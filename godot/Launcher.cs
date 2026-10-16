using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Launcher {
    [STAThread]
    private static void Main(string[] args) {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string engine = Path.Combine(root, "runtime", "Godot.exe");
        string game = Path.Combine(root, "game");
        if (!File.Exists(engine) || !File.Exists(Path.Combine(game, "project.godot"))) {
            MessageBox.Show("请先解压整个游戏文件夹，再启动。runtime 与 game 文件夹需要保留。", "万象棋局");
            return;
        }
        try {
            string cache = Path.Combine(game, ".godot", "global_script_class_cache.cfg");
            if (!File.Exists(cache)) {
                var setup = new ProcessStartInfo(engine, "--headless --editor --import --quit --path \"" + game + "\"");
                setup.UseShellExecute = false;
                setup.CreateNoWindow = true;
                using (var process = Process.Start(setup)) {
                    process.WaitForExit();
                    if (process.ExitCode != 0) throw new Exception("首次准备失败，请保留完整目录后重试。");
                }
            }
            string suffix = args.Length > 0 && args[0] == "--theater" ? " -- --qa --demo=10" : args.Length > 0 && args[0] == "--endgame" ? " -- --qa --demo=-2" : "";
            var start = new ProcessStartInfo(engine, "--path \"" + game + "\"" + suffix);
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.WorkingDirectory = game;
            Process.Start(start);
        } catch (Exception error) {
            MessageBox.Show("启动失败：" + error.Message, "万象棋局");
        }
    }
}
