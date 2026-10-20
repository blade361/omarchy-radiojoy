// Native helpers for radiojoy-agent.ps1: wallpaper, settings broadcast, lock detection,
// and the window borders. Kept to C# 5 for Windows PowerShell 5.1's compiler.
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

public static class RadiojoyNative
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool SystemParametersInfo(uint action, uint param, string value, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, UIntPtr w, string l, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll")] static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] static extern bool SwitchDesktop(IntPtr desktop);
    [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr icon);

    public static bool SetWallpaper(string path)
    {
        // SPI_SETDESKWALLPAPER, saved to the profile and announced to other programs
        return SystemParametersInfo(0x14, 0, path, 3);
    }

    // WM_SETTINGCHANGE, e.g. "ImmersiveColorSet" after the accent colour changed
    public static void Broadcast(string area)
    {
        UIntPtr r;
        SendMessageTimeout((IntPtr)0xffff, 0x1A, UIntPtr.Zero, area, 2, 1000, out r);
    }

    // The input desktop can't be switched to while the lock screen is up.
    public static bool IsLocked()
    {
        IntPtr d = OpenInputDesktop(0, false, 0x0100);
        if (d == IntPtr.Zero) return true;
        bool ok = SwitchDesktop(d);
        CloseDesktop(d);
        return !ok;
    }
}

// Windows 11 window borders and title bars in the wallpaper character's colours: the
// focused window's border slowly runs through the gradient (like the animated Hyprland
// border), the others get the quiet inactive colour.
public static class RadiojoyBorders
{
    delegate bool EnumProc(IntPtr hwnd, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    const int BORDER = 34, CAPTION = 35, TEXT = 36;
    const int DEFAULT = unchecked((int)0xFFFFFFFF);

    static readonly object gate = new object();
    static int[] stops = new int[0];
    static int inactive, caption, text, version;
    static bool on;
    static Thread thread;
    static readonly Dictionary<IntPtr, int> done = new Dictionary<IntPtr, int>();

    // Colours are 0xRRGGBB. An empty gradient turns it all off (windows go back to normal).
    public static void Set(int[] gradient, int inactiveColor, int captionColor, int textColor)
    {
        lock (gate)
        {
            stops = new int[gradient.Length];
            for (int i = 0; i < gradient.Length; i++) stops[i] = Ref(gradient[i]);
            inactive = Ref(inactiveColor); caption = Ref(captionColor); text = Ref(textColor);
            on = gradient.Length > 0;
            version++;
        }
        if (thread == null)
        {
            thread = new Thread(Run);
            thread.IsBackground = true;
            thread.Start();
        }
    }

    public static void Off()
    {
        Set(new int[0], 0, 0, 0);
        Thread.Sleep(300);
        lock (gate) { ResetAll(); }
    }

    static int Ref(int rgb) { return ((rgb & 0xff) << 16) | (rgb & 0xff00) | ((rgb >> 16) & 0xff); }

    static void Attr(IntPtr h, int attr, int value) { DwmSetWindowAttribute(h, attr, ref value, 4); }

    static void ResetAll()
    {
        foreach (IntPtr h in done.Keys)
            if (IsWindow(h)) { Attr(h, BORDER, DEFAULT); Attr(h, CAPTION, DEFAULT); Attr(h, TEXT, DEFAULT); }
        done.Clear();
    }

    static int Mix(int a, int b, double t)
    {
        int r = (int)(((a >> 16) & 0xff) * (1 - t) + ((b >> 16) & 0xff) * t);
        int g = (int)(((a >> 8) & 0xff) * (1 - t) + ((b >> 8) & 0xff) * t);
        int bl = (int)((a & 0xff) * (1 - t) + (b & 0xff) * t);
        return (r << 16) | (g << 8) | bl;
    }

    static void Run()
    {
        IntPtr lastFg = IntPtr.Zero;
        int tick = 0, seen = -1;
        while (true)
        {
            try
            {
                lock (gate)
                {
                    if (!on)
                    {
                        if (seen != version) { ResetAll(); seen = version; lastFg = IntPtr.Zero; }
                    }
                    else
                    {
                        if (seen != version || tick % 25 == 0)
                        {
                            bool fresh = seen != version;
                            seen = version;
                            EnumWindows(delegate (IntPtr h, IntPtr l)
                            {
                                int ver;
                                if (IsWindowVisible(h) && (GetWindowLong(h, -16) & 0x00C00000) == 0x00C00000 &&
                                    (fresh || !done.TryGetValue(h, out ver) || ver != version))
                                {
                                    Attr(h, CAPTION, caption); Attr(h, TEXT, text); Attr(h, BORDER, inactive);
                                    done[h] = version;
                                }
                                return true;
                            }, IntPtr.Zero);
                            var gone = new List<IntPtr>();
                            foreach (IntPtr h in done.Keys) if (!IsWindow(h)) gone.Add(h);
                            foreach (IntPtr h in gone) done.Remove(h);
                            lastFg = IntPtr.Zero;
                        }
                        IntPtr fg = GetForegroundWindow();
                        if (fg != lastFg && lastFg != IntPtr.Zero && done.ContainsKey(lastFg)) Attr(lastFg, BORDER, inactive);
                        lastFg = fg;
                        if (done.ContainsKey(fg) && stops.Length > 0)
                        {
                            // once round the gradient every 6 seconds
                            double pos = (Environment.TickCount & int.MaxValue) % 6000 / 6000.0 * stops.Length;
                            int i = (int)pos;
                            int c = Mix(stops[i % stops.Length], stops[(i + 1) % stops.Length], pos - i);
                            Attr(fg, BORDER, c);
                        }
                    }
                }
            }
            catch (Exception) { }
            tick++;
            Thread.Sleep(40);
        }
    }
}
