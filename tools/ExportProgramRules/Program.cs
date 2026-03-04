using System.Globalization;
using System.Text;
using System.Text.Json;
using CsvHelper;
using CsvHelper.Configuration;

namespace ExportProgramRules;
/// <summary>
/// Exportiert programRules aus einer JSON-Datei in eine CSV-Datei.
/// Löst dabei die programStage-IDs in lesbare Namen auf.
/// </summary>
class Program
{
    // Python-Vergleich: Das ist wie "if __name__ == '__main__':" in Python
    // Main ist der Einstiegspunkt für C#-Programme
    static void Main(string[] args)
    {
        try
        {
            // Standard-Pfade relativ zum Tool-Verzeichnis
            // Python-Vergleich: os.path.join()
            string defaultInputPath = Path.Combine("..", "..", "metadata", "metadata_Program Stage_Rule Action_Rule.json");
            string defaultOutputPath = Path.Combine("..", "..", "metadata", "common", "programRules", "programRules.csv");

            // Kommandozeilenargumente verarbeiten (optional)
            // Python-Vergleich: sys.argv[1], sys.argv[2]
            string inputPath = args.Length > 0 ? args[0] : defaultInputPath;
            string outputPath = args.Length > 1 ? args[1] : defaultOutputPath;

            // Absolute Pfade ermitteln
            inputPath = Path.GetFullPath(inputPath);
            outputPath = Path.GetFullPath(outputPath);

            Console.WriteLine($"Lese JSON-Datei: {inputPath}");
            Console.WriteLine($"Schreibe CSV-Datei: {outputPath}");
            Console.WriteLine();

            // JSON-Datei einlesen und parsen
            // Python-Vergleich: with open('file.json') as f: data = json.load(f)
            string jsonContent = File.ReadAllText(inputPath, Encoding.UTF8);
            
            // JsonDocument ist wie json.loads() in Python
            using JsonDocument doc = JsonDocument.Parse(jsonContent);
            JsonElement root = doc.RootElement;

            // 1. Schritt: programStages-Lookup erstellen (ID -> Name)
            // Python-Vergleich: stages_by_id = {stage['id']: stage['name'] for stage in data['programStages']}
            Console.WriteLine("Erstelle programStage-Lookup...");
            var stagesById = new Dictionary<string, string>();

            if (root.TryGetProperty("programStages", out JsonElement stagesArray))
            {
                // foreach ist wie "for stage in stages:" in Python
                foreach (JsonElement stage in stagesArray.EnumerateArray())
                {
                    string? id = stage.GetProperty("id").GetString();
                    string? name = stage.GetProperty("name").GetString();
                    
                    if (id != null && name != null)
                    {
                        stagesById[id] = name;
                    }
                }
            }
            
            Console.WriteLine($"  -> {stagesById.Count} programStages gefunden");
            Console.WriteLine();

            // 2. Schritt: programRules verarbeiten
            // Python-Vergleich: rules = []
            var csvRows = new List<ProgramRuleCsvRow>();

            if (root.TryGetProperty("programRules", out JsonElement rulesArray))
            {
                Console.WriteLine("Verarbeite programRules...");
                
                // Iteration über alle Rules
                foreach (JsonElement rule in rulesArray.EnumerateArray())
                {
                    // name und description extrahieren
                    // Python-Vergleich: name = rule.get('name', '')
                    string name = rule.TryGetProperty("name", out JsonElement nameElement) 
                        ? nameElement.GetString() ?? "" 
                        : "";
                    
                    string description = rule.TryGetProperty("description", out JsonElement descElement) 
                        ? descElement.GetString() ?? "" 
                        : "";

                    // programStage-ID in Namen auflösen
                    string programStageName = "";
                    if (rule.TryGetProperty("programStage", out JsonElement stageElement) &&
                        stageElement.TryGetProperty("id", out JsonElement stageIdElement))
                    {
                        string? stageId = stageIdElement.GetString();
                        if (stageId != null && stagesById.TryGetValue(stageId, out string? stageName))
                        {
                            programStageName = stageName;
                        }
                    }

                    // CSV-Zeile erstellen
                    // Python-Vergleich: rules.append({'name': name, 'description': desc, ...})
                    csvRows.Add(new ProgramRuleCsvRow
                    {
                        Name = name,
                        Description = description,
                        ProgramStage = programStageName
                    });
                }
                
                Console.WriteLine($"  -> {csvRows.Count} programRules verarbeitet");
            }

            // 3. Schritt: CSV-Datei schreiben
            Console.WriteLine();
            Console.WriteLine("Schreibe CSV-Datei...");

            // Stelle sicher, dass das Zielverzeichnis existiert
            // Python-Vergleich: os.makedirs(os.path.dirname(output_path), exist_ok=True)
            string? outputDir = Path.GetDirectoryName(outputPath);
            if (outputDir != null && !Directory.Exists(outputDir))
            {
                Directory.CreateDirectory(outputDir);
            }

            // CSV-Konfiguration
            // Python-Vergleich: csv.writer mit quoting=csv.QUOTE_MINIMAL
            // CsvHelper quoted automatisch Felder mit Kommas, Anführungszeichen oder Newlines
            var csvConfig = new CsvConfiguration(CultureInfo.InvariantCulture)
            {
                Encoding = Encoding.UTF8
                // Delimiter ist standardmäßig "," (Komma)
                // ShouldQuote wird von CsvHelper automatisch intelligent gehandhabt
            };

            // using ist wie Python's "with open()" - automatisches Schließen
            using (var writer = new StreamWriter(outputPath, false, Encoding.UTF8))
            using (var csv = new CsvWriter(writer, csvConfig))
            {
                // Header und Daten schreiben
                // Python-Vergleich: csv.DictWriter mit writeheader() und writerows()
                csv.WriteRecords(csvRows);
            }

            Console.WriteLine($"  -> {csvRows.Count} Zeilen geschrieben");
            Console.WriteLine();
            Console.WriteLine("✓ Erfolgreich abgeschlossen!");
        }
        catch (Exception ex)
        {
            // Python-Vergleich: except Exception as ex:
            Console.Error.WriteLine($"FEHLER: {ex.Message}");
            Console.Error.WriteLine(ex.StackTrace);
            Environment.Exit(1); // Python-Vergleich: sys.exit(1)
        }
    }
}

/// <summary>
/// Repräsentiert eine Zeile in der CSV-Ausgabedatei.
/// Python-Vergleich: Das ist wie eine dataclass oder ein dict
/// </summary>
public class ProgramRuleCsvRow
{
    // Properties sind wie Attribute in Python
    // Das "{ get; set; }" ist syntaktischer Zucker für getter/setter
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public string ProgramStage { get; set; } = "";
}
