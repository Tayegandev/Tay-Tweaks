using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace TMACs;

public sealed class MainForm : Form
{
    private readonly AppData _data = ProfileStore.Load();
    private readonly GlobalHooks _hooks;
    private readonly Stopwatch _recordClock = new();
    private readonly HashSet<int> _heldRecordingKeys = new();
    private MacroProfile Current => _data.Profiles.First(p => p.Id == _data.SelectedId);
    private bool _recording, _armed, _playing, _loading;
    private bool _startHeld;
    private readonly CheckBox _holdToPlay = new();
    private CancellationTokenSource? _runCts;
    private readonly Color BackgroundColor = Color.FromArgb(6, 11, 29);
    private readonly Color Surface = Color.FromArgb(14, 26, 57);
    private readonly Color SurfaceLight = Color.FromArgb(21, 39, 78);
    private readonly Color Accent = Color.FromArgb(42, 148, 255);
    private readonly Color Muted = Color.FromArgb(152, 174, 217);
    private readonly Font Ui = new("Segoe UI", 10);
    private readonly Font BoldUi = new("Segoe UI Semibold", 10);
    private readonly ListBox _profiles = new();
    private readonly DataGridView _grid = new();
    private readonly Label _status = new();
    private readonly Label _summary = new();
    private readonly Label _headerProfile = new();
    private readonly Button _recordButton = new();
    private readonly Button _playButton = new();
    private readonly Button _stopButton = new();
    private readonly NumericUpDown _defaultDelay = new();
    private readonly NumericUpDown _speed = new();
    private readonly CheckBox _loop = new();
    private readonly CheckBox _keyCapture = new();
    private readonly CheckBox _mouseCapture = new();
    private readonly CheckBox _moveCapture = new();
    private readonly ComboBox _startBind = new(), _stopBind = new();
    private readonly NotifyIcon _tray = new();
    private readonly System.Windows.Forms.Timer _refreshTimer = new() { Interval = 500 };
    private readonly ToolTip _tips = new();

    public MainForm()
    {
        Text = "TMAC's — Galaxy Macro Studio";
        MinimumSize = new Size(1050, 710);
        ClientSize = new Size(1200, 770);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = BackgroundColor;
        ForeColor = Color.White;
        Font = Ui;
        DoubleBuffered = true;
        try { Icon = new Icon(Path.Combine(AppContext.BaseDirectory, "Assets", "TMACs.ico")); }
        catch { /* EXE icon is embedded by the build. */ }

        if (_data.Profiles.Count == 0) _data.Profiles.Add(new MacroProfile { Name = "Default" });
        if (!_data.Profiles.Any(p => p.Id == _data.SelectedId))
            _data.SelectedId = _data.Profiles[0].Id;
        _data.Speed = Math.Clamp(_data.Speed, 0.1m, 10m);
        _data.DefaultDelay = Math.Clamp(_data.DefaultDelay, 0.5m, 60000m);

        BuildUI();
        LoadStateIntoUI();
        _hooks = new GlobalHooks
        {
            KeyboardInput = OnKeyEvent,
            MouseInput = OnMouseEvent,
            CaptureMovement = _data.RecordMovement
        };
        _tray.Icon = Icon;
        _tray.Text = "TMAC's — Idle";
        _tray.Visible = true;
        _tray.DoubleClick += (_, _) => RestoreFromTray();
        var context = new ContextMenuStrip();
        context.Items.Add("Open TMAC's", null, (_, _) => RestoreFromTray());
        context.Items.Add("Stop macro", null, (_, _) => StopEverything());
        context.Items.Add("Exit", null, (_, _) => Close());
        _tray.ContextMenuStrip = context;
        _refreshTimer.Tick += (_, _) => UpdateSummary();
        _refreshTimer.Start();
        FormClosing += (_, _) => {
            StopEverything();
            _hooks.Dispose(); _tray.Visible = false; _tray.Dispose();
            Save();
        };
        Resize += (_, _) => { if (WindowState == FormWindowState.Minimized) Hide(); };
    }

    private void BuildUI()
    {
        var outer = new TableLayoutPanel { Dock = DockStyle.Fill, BackColor = BackgroundColor,
            ColumnCount = 1, RowCount = 3, Padding = new Padding(17) };
        outer.RowStyles.Add(new RowStyle(SizeType.Absolute, 75));
        outer.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        outer.RowStyles.Add(new RowStyle(SizeType.Absolute, 37));
        Controls.Add(outer);

        var header = new Panel { Dock = DockStyle.Fill };
        outer.Controls.Add(header, 0, 0);
        var htitle = TextLabel("✦  TMAC's", 23, true, Color.White);
        htitle.Location = new Point(10, 2); htitle.AutoSize = true; header.Controls.Add(htitle);
        var hsub = TextLabel("GALAXY MACRO STUDIO  •  WINDOWS", 9, false, Muted);
        hsub.Location = new Point(13, 44); header.Controls.Add(hsub);
        var version = TextLabel("v1.0.0     LOCAL-ONLY", 9, false, Muted);
        version.Anchor = AnchorStyles.Right | AnchorStyles.Top;
        version.Location = new Point(905, 16); version.Size = new Size(235, 26);
        version.TextAlign = ContentAlignment.MiddleRight; header.Controls.Add(version);

        var columns = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 1,
            Padding = new Padding(0), BackColor = BackgroundColor };
        columns.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 230));
        columns.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        columns.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 255));
        outer.Controls.Add(columns, 0, 1);

        var left = Card();
        left.Padding = new Padding(15);
        left.Margin = new Padding(0, 0, 10, 0);
        columns.Controls.Add(left, 0, 0);
        left.Controls.Add(Place(TextLabel("PROFILES", 13, true), 14, 15, 175, 32));
        _profiles.Location = new Point(12, 62);
        _profiles.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        _profiles.Size = new Size(200, 380);
        _profiles.BackColor = Surface; _profiles.ForeColor = Color.White;
        _profiles.BorderStyle = BorderStyle.None; _profiles.Font = Ui;
        _profiles.ItemHeight = 34;
        _profiles.IntegralHeight = false;
        _profiles.SelectedIndexChanged += (_, _) => SelectProfile();
        left.Controls.Add(_profiles);
        var addProfile = ButtonUI("+ New profile", true);
        addProfile.Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        addProfile.SetBounds(12, 490, 200, 37);
        addProfile.Click += (_, _) => AddProfile();
        left.Controls.Add(addProfile);
        var rename = ButtonUI("Rename", false);
        rename.Anchor = AnchorStyles.Bottom | AnchorStyles.Left;
        rename.SetBounds(12, 535, 96, 35);
        rename.Click += (_, _) => RenameProfile();
        left.Controls.Add(rename);
        var delete = ButtonUI("Delete", false);
        delete.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
        delete.SetBounds(115, 535, 97, 35);
        delete.Click += (_, _) => DeleteProfile();
        left.Controls.Add(delete);
        left.Resize += (_, _) => {
            _profiles.Height = Math.Max(160, left.ClientSize.Height - 220);
            addProfile.Top = left.ClientSize.Height - 125;
            rename.Top = delete.Top = left.ClientSize.Height - 79;
            addProfile.Width = left.ClientSize.Width - 24;
            delete.Left = left.ClientSize.Width - 109;
            _profiles.Width = left.ClientSize.Width - 24;
        };

        var center = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2 };
        center.RowStyles.Add(new RowStyle(SizeType.Percent, 62));
        center.RowStyles.Add(new RowStyle(SizeType.Percent, 38));
        columns.Controls.Add(center, 1, 0);
        var editor = Card(); editor.Margin = new Padding(0, 0, 10, 10);
        center.Controls.Add(editor, 0, 0);
        _headerProfile.Text = "CURRENT MACRO"; _headerProfile.Font = new Font("Segoe UI Semibold", 15);
        _headerProfile.ForeColor = Color.White;
        _headerProfile.SetBounds(17, 14, 320, 35);
        _headerProfile.Anchor = AnchorStyles.Left | AnchorStyles.Top | AnchorStyles.Right;
        editor.Controls.Add(_headerProfile);
        _summary.ForeColor = Muted; _summary.SetBounds(18, 46, 380, 23);
        editor.Controls.Add(_summary);

        _grid.SetBounds(14, 81, 480, 330);
        _grid.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        _grid.BorderStyle = BorderStyle.None;
        _grid.BackgroundColor = Surface;
        _grid.GridColor = Color.FromArgb(33, 53, 93);
        _grid.EnableHeadersVisualStyles = false;
        _grid.ColumnHeadersDefaultCellStyle.BackColor = SurfaceLight;
        _grid.ColumnHeadersDefaultCellStyle.ForeColor = Color.White;
        _grid.ColumnHeadersDefaultCellStyle.Font = BoldUi;
        _grid.ColumnHeadersHeight = 34;
        _grid.RowHeadersVisible = false;
        _grid.AllowUserToAddRows = false;
        _grid.AllowUserToDeleteRows = false;
        _grid.AllowUserToResizeRows = false;
        _grid.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        _grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _grid.MultiSelect = false;
        _grid.DefaultCellStyle.BackColor = Surface;
        _grid.DefaultCellStyle.ForeColor = Color.White;
        _grid.DefaultCellStyle.SelectionBackColor = Color.FromArgb(30, 72, 141);
        _grid.DefaultCellStyle.SelectionForeColor = Color.White;
        _grid.DefaultCellStyle.Font = Ui;
        _grid.DefaultCellStyle.Padding = new Padding(4);
        _grid.RowTemplate.Height = 31;
        _grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Index", HeaderText = "#", ReadOnly = true, FillWeight = 12 });
        _grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Input", HeaderText = "INPUT", ReadOnly = true, FillWeight = 40 });
        _grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Kind", HeaderText = "EVENT", ReadOnly = true, FillWeight = 32 });
        _grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Delay", HeaderText = "DELAY (ms)", FillWeight = 27 });
        _grid.CellEndEdit += (_, e) => EditDelay(e.RowIndex);
        _grid.DataError += (_, _) => { };
        editor.Controls.Add(_grid);
        var editTools = new FlowLayoutPanel { Dock = DockStyle.Bottom, Height = 55, Padding = new Padding(11, 6, 3, 4), WrapContents = false };
        editor.Controls.Add(editTools);
        var clear = ButtonUI("Clear", false); clear.Width = 78;
        clear.Click += (_, _) => {
            if (_playing || _recording) return;
            Current.Steps.Clear(); RefreshSteps(); Save();
        };
        var remove = ButtonUI("Delete step", false); remove.Width = 100;
        remove.Click += (_, _) => EditStep("delete");
        var up = ButtonUI("↑", false); up.Width = 40; up.Click += (_, _) => EditStep("up");
        var down = ButtonUI("↓", false); down.Width = 40; down.Click += (_, _) => EditStep("down");
        foreach (var b in new[] { clear, remove, up, down }) {
            b.Height = 34; b.Margin = new Padding(0, 0, 6, 0); editTools.Controls.Add(b);
        }
        editor.Resize += (_, _) => {
            _grid.Width = editor.ClientSize.Width - 28;
            _grid.Height = Math.Max(100, editor.ClientSize.Height - 148);
            _headerProfile.Width = editor.ClientSize.Width - 30;
        };

        var recorder = Card(); recorder.Margin = new Padding(0, 0, 10, 0);
        center.Controls.Add(recorder, 0, 1);
        recorder.Controls.Add(Place(TextLabel("●  INPUT RECORDER", 13, true), 17, 13, 355, 30));
        recorder.Controls.Add(Place(TextLabel("Record in another window. F7 stops recording.", 9, false, Muted), 17, 44, 430, 25));
        _recordButton.Text = "●  Start test / Record";
        StyleButton(_recordButton, true);
        _recordButton.SetBounds(16, 78, 205, 40);
        _recordButton.Click += async (_, _) => await ToggleRecording();
        recorder.Controls.Add(_recordButton);
        var stopRec = ButtonUI("■  Stop recording", false);
        stopRec.SetBounds(228, 78, 185, 40);
        stopRec.Click += (_, _) => StopRecording();
        recorder.Controls.Add(stopRec);
        var config = new FlowLayoutPanel { Location = new Point(15, 126), Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top,
            Size = new Size(460, 32), WrapContents = false };
        recorder.Controls.Add(config);
        _keyCapture.Text = "Keyboard"; _keyCapture.Checked = true;
        _mouseCapture.Text = "Mouse"; _mouseCapture.Checked = true;
        _moveCapture.Text = "Movement";
        foreach (var c in new[] { _keyCapture, _mouseCapture, _moveCapture }) {
            c.Width = 117; c.ForeColor = Muted; c.FlatStyle = FlatStyle.Flat;
            c.CheckedChanged += (_, _) => SaveSettings();
            config.Controls.Add(c);
        }
        recorder.Controls.Add(Place(TextLabel("DEFAULT DELAY (ms)", 9, true, Muted), 17, 177, 174, 23));
        _defaultDelay.DecimalPlaces = 1; _defaultDelay.Increment = 0.5m;
        _defaultDelay.Minimum = 0.5m; _defaultDelay.Maximum = 60000m;
        _defaultDelay.SetBounds(196, 171, 104, 30);
        StyleNumber(_defaultDelay);
        _defaultDelay.ValueChanged += (_, _) => SaveSettings();
        recorder.Controls.Add(_defaultDelay);
        var quick = new FlowLayoutPanel { Location = new Point(16, 210), Size = new Size(440, 36),
            Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right, WrapContents = false };
        recorder.Controls.Add(quick);
        foreach (var value in new decimal[] { 0.5m, 1, 5, 10, 50 }) {
            var b = ButtonUI(value.ToString("0.#") + " ms", false); b.Width = 78; b.Height = 31;
            b.Click += (_, _) => { _defaultDelay.Value = value; };
            quick.Controls.Add(b);
        }
        recorder.Resize += (_, _) => { config.Width = recorder.ClientSize.Width - 30; quick.Width = recorder.ClientSize.Width - 30; };

        var right = Card(); right.Padding = new Padding(13);
        columns.Controls.Add(right, 2, 0);
        right.Controls.Add(Place(TextLabel("PLAYBACK", 13, true), 13, 14, 212, 30));
        _playButton.Text = "▶  Start macro";
        StyleButton(_playButton, true); _playButton.SetBounds(13, 58, 226, 47);
        _playButton.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        _playButton.Click += (_, _) => StartPlayback();
        right.Controls.Add(_playButton);
        _stopButton.Text = "■  STOP";
        StyleButton(_stopButton, false); _stopButton.SetBounds(13, 114, 226, 43);
        _stopButton.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        _stopButton.Click += (_, _) => StopEverything();
        right.Controls.Add(_stopButton);
        right.Controls.Add(Place(TextLabel("GLOBAL HOTKEYS", 11, true), 13, 192, 220, 28));
        right.Controls.Add(Place(TextLabel("Start", 9, false, Muted), 13, 229, 75, 27));
        right.Controls.Add(Place(TextLabel("Stop", 9, false, Muted), 13, 270, 75, 27));
        var keys = Enumerable.Range(1, 12).Select(i => "F" + i)
            .Concat(Enumerable.Range(0, 26).Select(i => ((char)('A' + i)).ToString()))
            .Concat(Enumerable.Range(0, 10).Select(i => "D" + i))
            .Concat(new[] { "Insert", "Home", "End", "PageUp", "PageDown", "Pause",
                "Scroll", "Oemtilde", "OemMinus", "Oemplus", "OemOpenBrackets",
                "OemCloseBrackets", "OemPipe", "OemSemicolon", "OemQuotes" }).ToArray();
        foreach (var combo in new[] { _startBind, _stopBind }) {
            combo.DropDownStyle = ComboBoxStyle.DropDownList;
            combo.Items.AddRange(keys); combo.ForeColor = Color.White; combo.BackColor = SurfaceLight;
            combo.FlatStyle = FlatStyle.Flat;
            combo.Width = 123; combo.Height = 27;
            combo.SelectedIndexChanged += (_, _) => SaveSettings();
            right.Controls.Add(combo);
        }
        _startBind.Location = new Point(111, 228);
        _stopBind.Location = new Point(111, 269);
        right.Controls.Add(Place(TextLabel("REPEAT / SPEED", 11, true), 13, 331, 220, 30));
        _loop.Text = "Loop until stopped"; _loop.ForeColor = Color.White;
        _loop.SetBounds(13, 365, 220, 29);
        _loop.CheckedChanged += (_, _) => SaveSettings();
        right.Controls.Add(_loop);
        _holdToPlay.Text = "Hold start key to repeat";
        _holdToPlay.ForeColor = Color.White;
        _holdToPlay.SetBounds(13, 391, 226, 28);
        _holdToPlay.CheckedChanged += (_, _) => {
            if (_holdToPlay.Checked) _loop.Checked = true;
            SaveSettings();
        };
        right.Controls.Add(_holdToPlay);
        right.Controls.Add(Place(TextLabel("Playback speed", 9, false, Muted), 13, 447, 140, 28));
        _speed.Minimum = 0.1m; _speed.Maximum = 10m; _speed.Increment = 0.1m;
        _speed.DecimalPlaces = 1; _speed.SetBounds(143, 443, 90, 30);
        StyleNumber(_speed); _speed.ValueChanged += (_, _) => SaveSettings();
        right.Controls.Add(_speed);
        var note = TextLabel("0.5 ms is a setting, not a guaranteed Windows timing. Some games block injected input.", 9, false, Muted);
        note.SetBounds(13, 502, 218, 80); note.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        right.Controls.Add(note);
        var btnOpen = ButtonUI("Open profiles folder", false);
        btnOpen.SetBounds(13, 596, 226, 39);
        btnOpen.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom;
        btnOpen.Click += (_, _) => {
            Directory.CreateDirectory(ProfileStore.Folder);
            Process.Start(new ProcessStartInfo("explorer.exe", ProfileStore.Folder) { UseShellExecute = true });
        };
        right.Controls.Add(btnOpen);
        right.Resize += (_, _) => {
            _playButton.Width = _stopButton.Width = btnOpen.Width = right.ClientSize.Width - 26;
            _startBind.Left = _stopBind.Left = right.ClientSize.Width - 140;
            _speed.Left = right.ClientSize.Width - 105;
            btnOpen.Top = right.ClientSize.Height - 54;
        };

        var footer = new Panel { Dock = DockStyle.Fill };
        outer.Controls.Add(footer, 0, 2);
        _status.ForeColor = Color.FromArgb(115, 207, 255);
        _status.Text = "●  Ready  •  F6 starts  •  F7 emergency stop";
        _status.Dock = DockStyle.Fill;
        _status.TextAlign = ContentAlignment.MiddleLeft;
        footer.Controls.Add(_status);
    }

    private Panel Card()
    {
        var p = new RoundedPanel { Dock = DockStyle.Fill, Radius = 17, BackColor = Surface };
        return p;
    }
    private static Control Place(Control c, int x, int y, int w, int h)
    { c.SetBounds(x, y, w, h); return c; }
    private Label TextLabel(string text, int fontSize, bool bold = false, Color? color = null)
        => new() { Text = text, Font = new Font("Segoe UI", fontSize,
                bold ? FontStyle.Bold : FontStyle.Regular),
            ForeColor = color ?? Color.White, AutoEllipsis = true };
    private Button ButtonUI(string label, bool primary)
    {
        var b = new Button { Text = label };
        StyleButton(b, primary);
        return b;
    }
    private void StyleButton(Button b, bool primary)
    {
        b.FlatStyle = FlatStyle.Flat;
        b.BackColor = primary ? Color.FromArgb(20, 99, 219) : SurfaceLight;
        b.ForeColor = Color.White;
        b.FlatAppearance.BorderColor = primary ? Accent : Color.FromArgb(38, 65, 107);
        b.FlatAppearance.BorderSize = 1;
        b.Cursor = Cursors.Hand; b.Font = BoldUi;
    }
    private void StyleNumber(NumericUpDown n)
    {
        n.BackColor = SurfaceLight; n.ForeColor = Color.White;
        n.BorderStyle = BorderStyle.FixedSingle; n.Font = Ui;
    }

    private void LoadStateIntoUI()
    {
        _loading = true;
        _keyCapture.Checked = _data.RecordKeyboard;
        _mouseCapture.Checked = _data.RecordMouse;
        _moveCapture.Checked = _data.RecordMovement;
        _loop.Checked = _data.Loop;
        _holdToPlay.Checked = _data.HoldToPlay;
        _speed.Value = _data.Speed;
        _defaultDelay.Value = _data.DefaultDelay;
        _startBind.SelectedItem = _data.StartHotkey;
        _stopBind.SelectedItem = _data.StopHotkey;
        if (_startBind.SelectedIndex < 0) _startBind.SelectedItem = "F6";
        if (_stopBind.SelectedIndex < 0) _stopBind.SelectedItem = "F7";
        _loading = false;
        ReloadProfiles();
        RefreshSteps();
        UpdateSummary();
    }
    private void SaveSettings()
    {
        if (_loading) return;
        _data.RecordKeyboard = _keyCapture.Checked;
        _data.RecordMouse = _mouseCapture.Checked;
        _data.RecordMovement = _moveCapture.Checked;
        _data.Loop = _loop.Checked;
        _data.HoldToPlay = _holdToPlay.Checked;
        _data.Speed = _speed.Value;
        _data.DefaultDelay = _defaultDelay.Value;
        _data.StartHotkey = _startBind.SelectedItem?.ToString() ?? "F6";
        _data.StopHotkey = _stopBind.SelectedItem?.ToString() ?? "F7";
        if (_data.StartHotkey == _data.StopHotkey) {
            _data.StopHotkey = "F7" == _data.StartHotkey ? "F8" : "F7";
            _loading = true; _stopBind.SelectedItem = _data.StopHotkey; _loading = false;
        }
        if (_hooks != null) _hooks.CaptureMovement = _data.RecordMovement;
        Save();
    }
    private void Save() { try { ProfileStore.Save(_data); } catch { SetStatus("Could not save profiles."); } }
    private void ReloadProfiles()
    {
        _loading = true;
        _profiles.Items.Clear();
        foreach (var p in _data.Profiles) _profiles.Items.Add(p);
        int index = _data.Profiles.FindIndex(p => p.Id == _data.SelectedId);
        _profiles.SelectedIndex = index;
        _loading = false;
    }
    private void SelectProfile()
    {
        if (_loading || _recording || _armed || _playing || _profiles.SelectedItem is not MacroProfile p) return;
        _data.SelectedId = p.Id; RefreshSteps(); Save();
    }
    private void AddProfile()
    {
        if (_recording || _playing || _armed) return;
        var p = new MacroProfile { Name = "Macro " + (_data.Profiles.Count + 1) };
        _data.Profiles.Add(p); _data.SelectedId = p.Id;
        ReloadProfiles(); RefreshSteps(); Save();
    }
    private void RenameProfile()
    {
        if (_recording || _playing || _armed) return;
        string name = PromptName(Current.Name);
        if (string.IsNullOrWhiteSpace(name)) return;
        Current.Name = name.Trim();
        ReloadProfiles(); RefreshSteps(); Save();
    }
    private void DeleteProfile()
    {
        if (_recording || _playing || _armed) return;
        if (_data.Profiles.Count <= 1) { SetStatus("Keep at least one profile."); return; }
        _data.Profiles.Remove(Current); _data.SelectedId = _data.Profiles[0].Id;
        ReloadProfiles(); RefreshSteps(); Save();
    }
    private string PromptName(string value)
    {
        using var f = new Form { Text = "Profile name", Size = new Size(350, 155),
            StartPosition = FormStartPosition.CenterParent, FormBorderStyle = FormBorderStyle.FixedDialog,
            MaximizeBox = false, MinimizeBox = false, BackColor = Surface };
        var t = new TextBox { Text = value, Left = 18, Top = 17, Width = 295 };
        var b = new Button { Text = "Save", Left = 213, Top = 60, Width = 100,
            DialogResult = DialogResult.OK };
        f.Controls.AddRange(new Control[] { t, b }); f.AcceptButton = b;
        return f.ShowDialog(this) == DialogResult.OK ? t.Text : "";
    }
    private void RefreshSteps()
    {
        if (_grid == null || _headerProfile == null || _data.Profiles.Count == 0) return;
        _grid.Rows.Clear();
        _headerProfile.Text = Current.Name;
        int index = 0;
        foreach (var s in Current.Steps)
        {
            string key = s.Kind.StartsWith("Key") ? ((Keys)s.Code).ToString()
                : (s.Kind == "Move" ? $"({s.X}, {s.Y})" : s.Kind);
            _grid.Rows.Add(++index, key, s.Kind, s.DelayMs.ToString("0.###"));
        }
        UpdateSummary();
    }
    private void UpdateSummary()
    {
        if (_data.Profiles.Count == 0) return;
        _summary.Text = $"{Current.Steps.Count} events  •  {Current.Steps.Sum(x => x.DelayMs):0.##} ms recorded delays";
        _playButton.Text = $"▶  Start macro ({_data.StartHotkey})";
        _stopButton.Text = $"■  Stop ({_data.StopHotkey})";
    }
    private void EditDelay(int index)
    {
        if (_loading || _playing || _recording || _armed || index < 0 || index >= Current.Steps.Count) return;
        var s = Current.Steps[index];
        var text = Convert.ToString(_grid.Rows[index].Cells["Delay"].Value);
        if (double.TryParse(text, System.Globalization.NumberStyles.Float,
            System.Globalization.CultureInfo.InvariantCulture, out double delay) &&
            double.IsFinite(delay) && delay >= 0.5 && delay <= 60000)
        {
            s.DelayMs = delay; Save();
        }
        else SetStatus("Delay must be between 0.5 and 60000 ms.");
        RefreshSteps();
    }
    private void EditStep(string action)
    {
        if (_recording || _armed || _playing || _grid.CurrentRow == null) return;
        int i = _grid.CurrentRow.Index;
        if (i < 0 || i >= Current.Steps.Count) return;
        var steps = Current.Steps;
        if (action == "delete") steps.RemoveAt(i);
        if (action == "up" && i > 0) (steps[i - 1], steps[i]) = (steps[i], steps[i - 1]);
        if (action == "down" && i < steps.Count - 1) (steps[i + 1], steps[i]) = (steps[i], steps[i + 1]);
        RefreshSteps(); Save();
    }

    private async Task ToggleRecording()
    {
        if (_recording || _armed) { StopRecording(); return; }
        if (_playing) return;
        Current.Steps.Clear(); RefreshSteps();
        _heldRecordingKeys.Clear();
        _armed = true;
        _recordButton.Text = "Arming...";
        SetStatus("Switch to your game/window. Recording begins in 3 seconds...");
        try { await Task.Delay(3000); }
        catch { }
        if (!_armed || IsDisposed) return;
        _armed = false; _recording = true;
        _recordClock.Restart();
        _recordButton.Text = "●  Recording...";
        SetStatus("Recording keys and mouse. Press stop hotkey to finish.");
    }
    private void StopRecording()
    {
        if (!_recording && !_armed) return;
        _armed = false; _recording = false;
        _recordClock.Stop(); _heldRecordingKeys.Clear();
        _recordButton.Text = "●  Start test / Record";
        RefreshSteps(); Save();
        SetStatus("Recording saved. Edit individual delays, then start playback.");
    }
    private bool OnKeyEvent(int code, int scanCode, bool extended, bool down)
    {
        if (code == (int)Keys.Escape && down && _playing)
        {
            BeginInvoke((Action)StopEverything);
            return false;
        }
        bool isStop = code == HotkeyCode(_data.StopHotkey);
        bool isStart = code == HotkeyCode(_data.StartHotkey);
        if (isStop && down) {
            BeginInvoke((Action)StopEverything);
            return true;
        }
        if (isStart && !_recording && !_armed)
        {
            if (down && !_startHeld)
            {
                _startHeld = true;
                BeginInvoke((Action)StartPlayback);
            }
            else if (!down)
            {
                _startHeld = false;
                if (_data.HoldToPlay) BeginInvoke((Action)StopPlaybackOnly);
            }
            return true;
        }
        if (isStop || isStart) return _recording;
        if (!_recording || !_keyCapture.Checked) return false;
        if (down && !_heldRecordingKeys.Add(code)) return false;
        if (!down) _heldRecordingKeys.Remove(code);
        AddRecorded(new MacroStep { Kind = down ? "KeyDown" : "KeyUp", Code = code, ScanCode = scanCode, Extended = extended });
        return false;
    }
    private void OnMouseEvent(MacroStep step)
    {
        if (!_recording || !_mouseCapture.Checked) return;
        if (step.Kind == "Move" && !_moveCapture.Checked) return;
        AddRecorded(step);
    }
    private void AddRecorded(MacroStep step)
    {
        if (!_recording || Current.Steps.Count >= 10000) {
            if (Current.Steps.Count >= 10000 && _recording)
                BeginInvoke((Action)StopRecording);
            return;
        }
        step.DelayMs = Math.Max(0.5, _recordClock.Elapsed.TotalMilliseconds);
        _recordClock.Restart();
        Current.Steps.Add(step);
        // UI rendering is throttled to avoid blocking the global hook callback.
        if (Current.Steps.Count % 10 == 0) BeginInvoke((Action)RefreshSteps);
    }
    private static int HotkeyCode(string name)
        => Enum.TryParse<Keys>(name, out var key) ? (int)key : (int)Keys.F7;

    private async void StartPlayback()
    {
        if ((_data.HoldToPlay && !_startHeld && !Focused && !ContainsFocus) || _playing || _recording || _armed || Current.Steps.Count == 0) {
            if (Current.Steps.Count == 0) SetStatus("Record some steps first.");
            return;
        }
        // Snapshot so edits/profile changes cannot mutate an in-flight macro.
        var steps = Current.Steps.Select(s => s.Copy()).ToArray();
        var token = new CancellationTokenSource(); _runCts = token;
        _playing = true;
        SetStatus(_holdToPlay.Checked ? "▶  Hold start key to repeat; release to stop." : "▶  Playing. Press stop hotkey or Escape to stop.");
        try {
            await MacroRunner.Run(steps, (double)_speed.Value, _loop.Checked || _holdToPlay.Checked, _data.UseScanCodes, token.Token);
        }
        catch (OperationCanceledException) { }
        catch (Exception ex) { SetStatus("Playback error: " + ex.Message); }
        finally {
            _playing = false;
            if (ReferenceEquals(_runCts, token)) _runCts = null;
            token.Dispose();
            SetStatus("●  Ready");
        }
    }
    private void StopPlaybackOnly() => _runCts?.Cancel();
    private void StopEverything()
    {
        StopRecording();
        _startHeld = false;
        _runCts?.Cancel();
        SetStatus("■  Stopping...");
    }
    private void RestoreFromTray()
    {
        Show(); WindowState = FormWindowState.Normal;
        Activate();
    }
    private void SetStatus(string message)
    {
        if (IsDisposed) return;
        if (InvokeRequired) { BeginInvoke((Action)(() => SetStatus(message))); return; }
        _status.Text = message;
        _tray.Text = message.Length < 60 ? "TMAC's: " + message : "TMAC's";
    }
}

public sealed class RoundedPanel : Panel
{
    public int Radius { get; set; } = 16;
    public RoundedPanel() { DoubleBuffered = true; }
    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        using var path = RoundedRect(ClientRectangle, Radius);
        Region?.Dispose(); Region = new Region(path);
        Invalidate();
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var bounds = new Rectangle(1, 1, Math.Max(1, Width - 3), Math.Max(1, Height - 3));
        using var path = RoundedRect(bounds, Radius);
        using var pen = new Pen(Color.FromArgb(44, 77, 131), 1.1f);
        e.Graphics.DrawPath(pen, path);
    }
    private static GraphicsPath RoundedRect(Rectangle r, int radius)
    {
        int d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
        var p = new GraphicsPath();
        p.AddArc(r.Left, r.Top, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Top, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.Left, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }
}