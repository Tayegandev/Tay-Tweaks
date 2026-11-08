using System.Runtime.InteropServices;
using System.Diagnostics;

namespace TMACs;

internal sealed class GlobalHooks : IDisposable
{
    private const int WH_KEYBOARD_LL = 13, WH_MOUSE_LL = 14;
    private const int WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104, WM_SYSKEYUP = 0x0105;
    private const int WM_MOUSEMOVE = 0x0200, WM_LBUTTONDOWN = 0x0201, WM_LBUTTONUP = 0x0202;
    private const int WM_RBUTTONDOWN = 0x0204, WM_RBUTTONUP = 0x0205;
    private const int WM_MBUTTONDOWN = 0x0207, WM_MBUTTONUP = 0x0208;
    private const int WM_MOUSEWHEEL = 0x020A;

    [StructLayout(LayoutKind.Sequential)] private struct KBDLLHOOKSTRUCT
    { public uint vkCode, scanCode, flags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)] private struct POINT { public int X, Y; }

    [StructLayout(LayoutKind.Sequential)] private struct MSLLHOOKSTRUCT
    { public POINT pt; public uint mouseData, flags, time; public IntPtr dwExtraInfo; }

    private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);
    private readonly HookProc _keyboardProc;
    private readonly HookProc _mouseProc;
    private IntPtr _keyboard, _mouse;
    private long _lastMove;

    public Func<int, bool, bool>? KeyboardInput { get; set; }
    public Action<MacroStep>? MouseInput { get; set; }
    public bool CaptureMovement { get; set; }

    public GlobalHooks()
    {
        _keyboardProc = KeyboardCallback;
        _mouseProc = MouseCallback;
        IntPtr module = GetModuleHandle(null);
        _keyboard = SetWindowsHookEx(WH_KEYBOARD_LL, _keyboardProc, module, 0);
        _mouse = SetWindowsHookEx(WH_MOUSE_LL, _mouseProc, module, 0);
        if (_keyboard == IntPtr.Zero || _mouse == IntPtr.Zero)
        {
            Dispose();
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),
                "Couldn't start global keyboard/mouse hooks.");
        }
    }

    private IntPtr KeyboardCallback(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0)
        {
            int message = wParam.ToInt32();
            if (message == WM_KEYDOWN || message == WM_KEYUP ||
                message == WM_SYSKEYDOWN || message == WM_SYSKEYUP)
            {
                var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);
                bool injected = (data.flags & 0x10) != 0;
                if (!injected)
                {
                    bool down = message == WM_KEYDOWN || message == WM_SYSKEYDOWN;
                    try
                    {
                        if (KeyboardInput?.Invoke((int)data.vkCode, down) == true)
                            return new IntPtr(1);
                    }
                    catch { /* Never break the system hook chain for an UI exception. */ }
                }
            }
        }
        return CallNextHookEx(_keyboard, code, wParam, lParam);
    }

    private IntPtr MouseCallback(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0)
        {
            int message = wParam.ToInt32();
            var m = Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);
            if ((m.flags & 1) == 0)
            {
                string? kind = message switch
                {
                    WM_LBUTTONDOWN => "LeftDown", WM_LBUTTONUP => "LeftUp",
                    WM_RBUTTONDOWN => "RightDown", WM_RBUTTONUP => "RightUp",
                    WM_MBUTTONDOWN => "MiddleDown", WM_MBUTTONUP => "MiddleUp",
                    WM_MOUSEWHEEL => "Wheel",
                    WM_MOUSEMOVE when CaptureMovement => "Move",
                    _ => null
                };
                if (kind != null)
                {
                    if (kind == "Move")
                    {
                        long now = Stopwatch.GetTimestamp();
                        if ((now - _lastMove) * 1000.0 / Stopwatch.Frequency < 30)
                            return CallNextHookEx(_mouse, code, wParam, lParam);
                        _lastMove = now;
                    }
                    int delta = kind == "Wheel" ? unchecked((short)(m.mouseData >> 16)) : 0;
                    try
                    {
                        MouseInput?.Invoke(new MacroStep { Kind = kind, X = m.pt.X,
                            Y = m.pt.Y, Code = delta });
                    }
                    catch { }
                }
            }
        }
        return CallNextHookEx(_mouse, code, wParam, lParam);
    }

    public void Dispose()
    {
        if (_keyboard != IntPtr.Zero) { UnhookWindowsHookEx(_keyboard); _keyboard = IntPtr.Zero; }
        if (_mouse != IntPtr.Zero) { UnhookWindowsHookEx(_mouse); _mouse = IntPtr.Zero; }
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string? lpModuleName);
}

internal static class InputInjector
{
    private const uint INPUT_MOUSE = 0, INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 2;
    private const uint MOUSEEVENTF_LEFTDOWN = 2, MOUSEEVENTF_LEFTUP = 4;
    private const uint MOUSEEVENTF_RIGHTDOWN = 8, MOUSEEVENTF_RIGHTUP = 16;
    private const uint MOUSEEVENTF_MIDDLEDOWN = 32, MOUSEEVENTF_MIDDLEUP = 64;
    private const uint MOUSEEVENTF_WHEEL = 0x0800;

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT { public uint type; public InputUnion U; }
    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx, dy; public uint mouseData, dwFlags, time; public UIntPtr dwExtraInfo;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk, wScan; public uint dwFlags, time; public UIntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, INPUT[] inputs, int size);
    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    public static void Emit(MacroStep s)
    {
        if (s.Kind == "Move") { SetCursorPos(s.X, s.Y); return; }
        if (s.Kind == "KeyDown" || s.Kind == "KeyUp")
        {
            var i = new INPUT { type = INPUT_KEYBOARD, U = new InputUnion {
                ki = new KEYBDINPUT { wVk = (ushort)s.Code,
                    dwFlags = s.Kind == "KeyUp" ? KEYEVENTF_KEYUP : 0 } } };
            SendInput(1, new[] { i }, Marshal.SizeOf<INPUT>());
            return;
        }
        uint flags = s.Kind switch
        {
            "LeftDown" => MOUSEEVENTF_LEFTDOWN, "LeftUp" => MOUSEEVENTF_LEFTUP,
            "RightDown" => MOUSEEVENTF_RIGHTDOWN, "RightUp" => MOUSEEVENTF_RIGHTUP,
            "MiddleDown" => MOUSEEVENTF_MIDDLEDOWN, "MiddleUp" => MOUSEEVENTF_MIDDLEUP,
            "Wheel" => MOUSEEVENTF_WHEEL, _ => 0
        };
        if (flags == 0) return;
        var input = new INPUT { type = INPUT_MOUSE, U = new InputUnion {
            mi = new MOUSEINPUT { dwFlags = flags, mouseData = unchecked((uint)s.Code) } } };
        SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>());
    }

    public static void ReleaseKeys(IEnumerable<int> keys)
    {
        foreach (int key in keys)
            Emit(new MacroStep { Kind = "KeyUp", Code = key });
    }
}

internal static class MacroRunner
{
    public static async Task Run(IReadOnlyList<MacroStep> steps, double speed, bool loop,
        CancellationToken ct)
    {
        var held = new HashSet<int>();
        try
        {
            do
            {
                foreach (var step in steps)
                {
                    ct.ThrowIfCancellationRequested();
                    await WaitDelay(Math.Clamp(step.DelayMs / speed, 0.5, 600000), ct)
                        .ConfigureAwait(false);
                    ct.ThrowIfCancellationRequested();
                    InputInjector.Emit(step);
                    if (step.Kind == "KeyDown") held.Add(step.Code);
                    if (step.Kind == "KeyUp") held.Remove(step.Code);
                }
                // Never keep keys pressed across loop boundaries.
                InputInjector.ReleaseKeys(held);
                held.Clear();
            } while (loop && !ct.IsCancellationRequested);
        }
        finally { InputInjector.ReleaseKeys(held); }
    }

    private static async Task WaitDelay(double ms, CancellationToken ct)
    {
        long start = Stopwatch.GetTimestamp();
        long target = start + (long)(ms * Stopwatch.Frequency / 1000.0);
        // Sleep when possible; spin only for the short remainder.
        if (ms >= 4)
            await Task.Delay(TimeSpan.FromMilliseconds(Math.Max(1, ms - 2)), ct)
                .ConfigureAwait(false);
        var spinner = new SpinWait();
        while (Stopwatch.GetTimestamp() < target)
        {
            ct.ThrowIfCancellationRequested();
            spinner.SpinOnce();
        }
    }
}