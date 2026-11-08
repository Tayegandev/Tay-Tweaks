using System.Text.Json;

namespace TMACs;

public sealed class MacroStep
{
    public string Kind { get; set; } = "KeyDown";
    public int Code { get; set; }
    public int ScanCode { get; set; }
    public bool Extended { get; set; }
    public int X { get; set; }
    public int Y { get; set; }
    public double DelayMs { get; set; } = 1.0;
    public MacroStep Copy() => (MacroStep)MemberwiseClone();
}

public sealed class MacroProfile
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get; set; } = "New macro";
    public List<MacroStep> Steps { get; set; } = new();
    public override string ToString() => Name;
}

public sealed class AppData
{
    public List<MacroProfile> Profiles { get; set; } = new();
    public string SelectedId { get; set; } = "";
    public string StartHotkey { get; set; } = "F6";
    public string StopHotkey { get; set; } = "F7";
    public bool RecordKeyboard { get; set; } = true;
    public bool RecordMouse { get; set; } = true;
    public bool RecordMovement { get; set; }
    public bool Loop { get; set; }
    public bool HoldToPlay { get; set; }
    public bool UseScanCodes { get; set; } = true;
    public decimal Speed { get; set; } = 1.0m;
    public decimal DefaultDelay { get; set; } = 1.0m;
}

public static class ProfileStore
{
    public static readonly string Folder = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TMACs");
    public static readonly string FilePath = Path.Combine(Folder, "profiles.json");

    public static AppData Load()
    {
        try
        {
            if (File.Exists(FilePath))
            {
                var model = JsonSerializer.Deserialize<AppData>(File.ReadAllText(FilePath));
                if (model != null) return model;
            }
        }
        catch { /* Corrupt or inaccessible settings: start in safe defaults. */ }
        return new AppData();
    }

    public static void Save(AppData data)
    {
        Directory.CreateDirectory(Folder);
        var tmp = FilePath + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(data,
            new JsonSerializerOptions { WriteIndented = true }));
        File.Move(tmp, FilePath, true);
    }
}