// Sixel frames for the Radiojoy terminal splash on Windows (radiojoy-sixel.ps1).
// Kept to C# 5 so Windows PowerShell 5.1's built-in compiler can build it.
using System;
using System.Collections.Generic;
using System.Text;

public static class RadiojoySixel
{
    // Pixels are 0xAARRGGBB. Pixels with alpha < 128 stay transparent.
    public static string Encode(int[] px, int w, int h)
    {
        // palette: the 255 most common 5-bit colour buckets, each the average of its pixels
        var count = new Dictionary<int, long[]>();
        for (int i = 0; i < px.Length; i++)
        {
            int c = px[i];
            if (((c >> 24) & 0xff) < 128) continue;
            int r = (c >> 16) & 0xff, g = (c >> 8) & 0xff, b = c & 0xff;
            int key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
            long[] acc;
            if (!count.TryGetValue(key, out acc)) { acc = new long[4]; count[key] = acc; }
            acc[0]++; acc[1] += r; acc[2] += g; acc[3] += b;
        }
        var keys = new List<int>(count.Keys);
        keys.Sort(delegate (int a, int b) { return count[b][0].CompareTo(count[a][0]); });
        int n = Math.Min(255, keys.Count);
        var pr = new int[n]; var pg = new int[n]; var pb = new int[n];
        var map = new Dictionary<int, int>();
        for (int i = 0; i < n; i++)
        {
            long[] a = count[keys[i]];
            pr[i] = (int)(a[1] / a[0]); pg[i] = (int)(a[2] / a[0]); pb[i] = (int)(a[3] / a[0]);
            map[keys[i]] = i;
        }
        // every other bucket goes to its nearest palette colour
        for (int k = n; k < keys.Count; k++)
        {
            long[] a = count[keys[k]];
            int r = (int)(a[1] / a[0]), g = (int)(a[2] / a[0]), b = (int)(a[3] / a[0]);
            int best = 0, bestD = int.MaxValue;
            for (int i = 0; i < n; i++)
            {
                int dr = r - pr[i], dg = g - pg[i], db = b - pb[i];
                int d = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
                if (d < bestD) { bestD = d; best = i; }
            }
            map[keys[k]] = best;
        }
        var idx = new int[px.Length];
        for (int i = 0; i < px.Length; i++)
        {
            int c = px[i];
            if (((c >> 24) & 0xff) < 128) { idx[i] = -1; continue; }
            int key = ((((c >> 16) & 0xff) >> 3) << 10) | ((((c >> 8) & 0xff) >> 3) << 5) | ((c & 0xff) >> 3);
            idx[i] = map[key];
        }

        var sb = new StringBuilder();
        // P2=1: pixels left at 0 keep the background (transparent)
        sb.Append("\x1bP0;1;0q\"1;1;").Append(w).Append(';').Append(h);
        for (int i = 0; i < n; i++)
            sb.Append('#').Append(i).Append(";2;").Append(pr[i] * 100 / 255).Append(';')
              .Append(pg[i] * 100 / 255).Append(';').Append(pb[i] * 100 / 255);
        var used = new bool[n];
        var row = new int[w];
        for (int y0 = 0; y0 < h; y0 += 6)
        {
            Array.Clear(used, 0, n);
            int y1 = Math.Min(h, y0 + 6);
            for (int y = y0; y < y1; y++)
                for (int x = 0; x < w; x++) { int c = idx[y * w + x]; if (c >= 0) used[c] = true; }
            bool first = true;
            for (int c = 0; c < n; c++)
            {
                if (!used[c]) continue;
                for (int x = 0; x < w; x++)
                {
                    int bits = 0;
                    for (int y = y0; y < y1; y++) if (idx[y * w + x] == c) bits |= 1 << (y - y0);
                    row[x] = bits;
                }
                int end = w;
                while (end > 0 && row[end - 1] == 0) end--;
                if (!first) sb.Append('$');
                first = false;
                sb.Append('#').Append(c);
                for (int x = 0; x < end; )
                {
                    int run = 1;
                    while (x + run < end && row[x + run] == row[x]) run++;
                    char ch = (char)(63 + row[x]);
                    if (run > 3) sb.Append('!').Append(run).Append(ch);
                    else sb.Append(ch, run);
                    x += run;
                }
            }
            sb.Append('-');
        }
        sb.Append("\x1b\\");
        return sb.ToString();
    }

    // Frame `step` (1..steps) of the radio static tuning in to the picture, as in the
    // Linux radiojoy-sixel: bands of rows slide sideways and blocks of the theme's
    // colours cover the figures, less and less on later steps.
    public static int[] Static(int[] img, int w, int h, int step, int steps, int block)
    {
        int[] pal = { unchecked((int)0xffdc2249), unchecked((int)0xffece9f7), unchecked((int)0xff7d82bc),
                      unchecked((int)0xff2b1a1d), unchecked((int)0xff9d99bc) };
        double noise = Math.Pow(1 - (step - 1) / (double)steps, 1.6) * 0.9;
        var rng = new Random(step * 7919);
        var f = (int[])img.Clone();
        int bh = (h + block - 1) / block, bw = (w + block - 1) / block;
        int[] shifts = { -3, -2, 2, 3 };
        for (int by = 0; by < bh; by++)
        {
            if (rng.NextDouble() >= noise * 0.4) continue;
            int s = shifts[rng.Next(4)] * block;
            for (int y = by * block; y < Math.Min(h, (by + 1) * block); y++)
                for (int x = 0; x < w; x++)
                {
                    int sx = ((x - s) % w + w) % w;
                    int src = img[y * w + sx];
                    if (Solid(img[y * w + x]) && ((src >> 24) & 0xff) > 0) f[y * w + x] = src;
                }
        }
        for (int by = 0; by < bh; by++)
            for (int bx = 0; bx < bw; bx++)
            {
                if (rng.NextDouble() >= noise) continue;
                int c = pal[rng.Next(pal.Length)];
                for (int y = by * block; y < Math.Min(h, (by + 1) * block); y++)
                    for (int x = bx * block; x < Math.Min(w, (bx + 1) * block); x++)
                        if (Solid(img[y * w + x])) f[y * w + x] = c;
            }
        return f;
    }

    // sixel transparency is on/off, so the edge is hardened like the Linux version
    public static void Harden(int[] px)
    {
        for (int i = 0; i < px.Length; i++)
            px[i] = Solid(px[i]) ? (px[i] | unchecked((int)0xff000000)) : 0;
    }

    static bool Solid(int c) { return ((c >> 24) & 0xff) > 110; }
}
