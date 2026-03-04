# C# Code Erklärung für Absolute Anfänger

Diese Datei erklärt **jeden Teil** des Programms ganz einfach, ohne Vorkenntnisse vorauszusetzen.

---

## 📋 Was macht das Programm?

Das Programm:
1. Liest eine große JSON-Datei
2. Sucht darin nach "programRules" und "programStages"
3. Schreibt die Informationen in eine CSV-Datei (Excel-Format)

---

## 🔝 Die ersten Zeilen (1-5)

```csharp
using System.Globalization;
using System.Text;
using System.Text.Json;
using CsvHelper;
using CsvHelper.Configuration;
```

### Was bedeutet `using`?

**Einfach erklärt:** "Ich brauche diese Werkzeugkästen!"

Stell dir vor, du baust etwas:
- `System.Text` = Werkzeugkasten für Text-Verarbeitung
- `System.Text.Json` = Werkzeugkasten für JSON-Dateien
- `CsvHelper` = Werkzeugkasten für CSV-Dateien

**Ohne `using`:** Du müsstest immer den vollen Namen schreiben:
```csharp
System.Text.Json.JsonDocument doc = ...  // LANG!
```

**Mit `using`:** Kurzer Name reicht:
```csharp
JsonDocument doc = ...  // KURZ!
```

---

## 🏷️ Namespace (Zeile 7)

```csharp
namespace ExportProgramRules;
```

### Was ist ein Namespace?

**Einfach erklärt:** Ein "Ordner" für deinen Code.

Stell dir vor:
```
Haus (Namespace)
├── Küche (Klasse)
├── Wohnzimmer (Klasse)
└── Schlafzimmer (Klasse)
```

Der vollständige Name der Küche ist: `Haus.Küche`

**Warum?** Damit es keine Verwechslungen gibt, wenn mehrere Programme eine "Küche" haben.

---

## 📝 Kommentar (Zeile 9-12)

```csharp
/// <summary>
/// Exportiert programRules aus einer JSON-Datei in eine CSV-Datei.
/// Löst dabei die programStage-IDs in lesbare Namen auf.
/// </summary>
```

### Was sind `///` Kommentare?

**Einfach erklärt:** Spezielle Kommentare, die Hilfe-Texte erzeugen.

- `//` = Normaler Kommentar (nur für dich)
- `///` = Dokumentations-Kommentar (erscheint in Hilfe-Fenstern)

Wenn du später in einem anderen Programm diese Klasse nutzt, siehst du diese Beschreibung!

---

## 🏛️ Klasse (Zeile 13)

```csharp
class Program
```

### Was ist eine Klasse?

**Einfach erklärt:** Ein "Bauplan" oder "Container" für Code.

Alles in C# muss in einer Klasse sein!

**Analogie:** 
- Auto-Bauplan = Klasse
- Echtes Auto = Objekt (erstellt aus der Klasse)

Hier ist `Program` unsere Hauptklasse.

---

## 🚀 Main-Methode (Zeile 17)

```csharp
static void Main(string[] args)
```

### Was bedeutet das?

Lass uns jedes Wort erklären:

#### `static`
**Bedeutet:** "Gehört zur Klasse, nicht zu einem Objekt"

**Einfach:** Du brauchst kein Objekt erstellen, um diese Methode zu nutzen.

#### `void`
**Bedeutet:** "Gibt nichts zurück"

**Einfach:** Die Methode macht etwas, aber liefert kein Ergebnis zurück.

**Andere Beispiele:**
```csharp
int Add(int a, int b)  // Gibt eine Zahl zurück
string GetName()        // Gibt Text zurück
void DoSomething()      // Gibt nichts zurück
```

#### `Main`
**Bedeutet:** Der Name der Methode

**Besonders:** `Main` ist IMMER der **Startpunkt** eines C#-Programms!

#### `string[] args`
**Bedeutet:** "Eine Liste von Text-Werten als Eingabe"

**Einfach:** Kommandozeilen-Argumente

Wenn du aufrufst: `programm.exe datei1.txt datei2.txt`
Dann ist: `args[0] = "datei1.txt"` und `args[1] = "datei2.txt"`

---

## 🛡️ Try-Catch (Zeile 19)

```csharp
try
{
    // Dein Code hier
}
catch (Exception ex)
{
    // Falls ein Fehler passiert
}
```

### Was ist Try-Catch?

**Einfach erklärt:** "Probiere das, und wenn es schief geht, fange den Fehler ab"

**Analogie:**
```
TRY (Versuche):
    - Öffne die Tür
    - Falls die Tür nicht existiert → FEHLER!
    
CATCH (Fange Fehler):
    - "Ups, Tür existiert nicht!"
    - Zeige Fehlermeldung
```

**Ohne Try-Catch:** Programm stürzt ab ❌  
**Mit Try-Catch:** Programm zeigt Fehlermeldung und beendet sauber ✅

---

## 📁 Pfade erstellen (Zeile 22-23)

```csharp
string defaultInputPath = Path.Combine("..", "..", "metadata", "metadata_Program Stage_Rule Action_Rule.json");
string defaultOutputPath = Path.Combine("..", "..", "metadata", "common", "programRules", "programRules.csv");
```

### Was macht `Path.Combine`?

**Einfach erklärt:** Baut einen Dateipfad zusammen.

**`..`** bedeutet: "Ein Ordner nach oben"

**Beispiel:**
```
Du bist hier: C:\tools\ExportProgramRules\

".." → C:\tools\
".." wieder → C:\

Also:
Path.Combine("..", "..", "metadata", "file.json")
= C:\metadata\file.json
```

**Warum `Path.Combine` statt einfach Text?**
- Windows nutzt `\` (Backslash)
- Linux/Mac nutzt `/` (Slash)
- `Path.Combine` wählt automatisch das Richtige!

---

## 🗂️ String Datentyp (Zeile 22)

```csharp
string defaultInputPath = ...
```

### Was ist `string`?

**Einfach erklärt:** Text-Datentyp

**Beispiele:**
```csharp
string name = "Max";
string text = "Hallo Welt";
string pfad = "C:\\Dateien\\dokument.txt";
```

**Wichtig:** Text steht immer in `"Anführungszeichen"`

---

## ❓ Ternärer Operator (Zeile 27-28)

```csharp
string inputPath = args.Length > 0 ? args[0] : defaultInputPath;
string outputPath = args.Length > 1 ? args[1] : defaultOutputPath;
```

### Was bedeutet `? :`?

**Einfach erklärt:** Eine Kurzform für IF-ELSE

**Langform:**
```csharp
string inputPath;
if (args.Length > 0)
{
    inputPath = args[0];
}
else
{
    inputPath = defaultInputPath;
}
```

**Kurzform (Ternärer Operator):**
```csharp
string inputPath = args.Length > 0 ? args[0] : defaultInputPath;
//                 ^^^^^^^^^^^^^^^^   ^^^^^^^^   ^^^^^^^^^^^^^^
//                 Bedingung          WAHR       FALSCH
```

**Lies es als:** "Wenn args.Length größer als 0, dann args[0], sonst defaultInputPath"

---

## 🌍 Absolute Pfade (Zeile 31-32)

```csharp
inputPath = Path.GetFullPath(inputPath);
outputPath = Path.GetFullPath(outputPath);
```

### Was macht `GetFullPath`?

**Einfach erklärt:** Macht aus relativem Pfad einen absoluten Pfad.

**Beispiel:**
```
Relativ:  ..\metadata\file.json
Absolut:  C:\Users\pifr10\dev\Surveillance-Toolkit\metadata\file.json
```

**Warum?** Absolute Pfade sind eindeutig, egal wo du das Programm ausführst.

---

## 🖨️ Console.WriteLine (Zeile 34-36)

```csharp
Console.WriteLine($"Lese JSON-Datei: {inputPath}");
Console.WriteLine($"Schreibe CSV-Datei: {outputPath}");
Console.WriteLine();
```

### Was macht `Console.WriteLine`?

**Einfach erklärt:** Schreibt Text in die Konsole (schwarzes Fenster).

**Drei Arten:**
```csharp
// 1. Normaler Text
Console.WriteLine("Hallo");

// 2. String-Interpolation (mit $)
Console.WriteLine($"Pfad: {inputPath}");
//                 ^      ^         ^
//                 $      {}=Platzhalter

// 3. Leere Zeile
Console.WriteLine();
```

**Das `$` Zeichen:** Aktiviert String-Interpolation (Variablen in Text einsetzen)

---

## 📖 Datei lesen (Zeile 39-40)

```csharp
string jsonContent = File.ReadAllText(inputPath, Encoding.UTF8);
```

### Was passiert hier?

**Einfach erklärt:** Liest die gesamte Datei als Text.

**Schritt für Schritt:**
1. `File.ReadAllText` = Methode zum Datei lesen
2. `inputPath` = Welche Datei?
3. `Encoding.UTF8` = Wie soll Text interpretiert werden? (UTF-8 für Umlaute!)
4. `string jsonContent` = Speichere den gesamten Inhalt hier

**Analogie:**
```
Buch aufschlagen → File.ReadAllText
Alles lesen → ReadAllText
In Gedächtnis speichern → string jsonContent
```

---

## 🔧 Using-Statement (Zeile 43)

```csharp
using JsonDocument doc = JsonDocument.Parse(jsonContent);
```

### Was bedeutet `using` hier?

**WICHTIG:** Das ist ein **anderes** `using` als ganz oben!

**Oben (Zeile 1-5):** Import von Werkzeugkästen  
**Hier (Zeile 43):** Automatisches Aufräumen nach Benutzung

**Einfach erklärt:** "Benutze das, und räume automatisch auf wenn fertig"

**Analogie:**
```
using Auto mieten
{
    Auto fahren
    Auto parken
} // Auto wird AUTOMATISCH zurückgegeben!
```

**Technisch:** Ruft automatisch `Dispose()` auf (gibt Speicher frei).

---

## 📊 JsonDocument (Zeile 43-44)

```csharp
using JsonDocument doc = JsonDocument.Parse(jsonContent);
JsonElement root = doc.RootElement;
```

### Was ist das?

#### `JsonDocument.Parse`
**Einfach erklärt:** Wandelt Text in JSON-Struktur um.

**Vorher:** `jsonContent = "{ name: 'Max', age: 30 }"` (nur Text!)  
**Nachher:** `doc` = Strukturiert, kann durchsucht werden

#### `RootElement`
**Einfach erklärt:** Das oberste Element der JSON-Struktur.

**JSON-Struktur:**
```json
{                    ← ROOT (Wurzel)
  "name": "Max",
  "age": 30
}
```

`root` zeigt auf die `{` ganz oben.

---

## 📝 Kommentar mit Kontext (Zeile 47-48)

```csharp
// 1. Schritt: programStages-Lookup erstellen (ID -> Name)
Console.WriteLine("Erstelle programStage-Lookup...");
```

### Was ist ein "Lookup"?

**Einfach erklärt:** Eine Nachschlagetabelle.

**Analogie:** Telefonbuch
```
ID (Schlüssel) → Name (Wert)
"YGow123"      → "Admission"
"NeCr456"      → "Discharge"
```

Später kannst du mit der ID den Namen finden!

---

## 📚 Dictionary (Zeile 49)

```csharp
var stagesById = new Dictionary<string, string>();
```

### Was ist ein Dictionary?

**Einfach erklärt:** Eine Sammlung von Schlüssel-Wert-Paaren.

**Aufbau:**
```csharp
Dictionary<KeyType, ValueType>
           ^        ^
           Schlüssel Wert
```

**In unserem Fall:**
```csharp
Dictionary<string, string>
           ^       ^
           ID      Name
```

**Beispiel-Nutzung:**
```csharp
// Hinzufügen
stagesById["YGow123"] = "Admission";
stagesById["NeCr456"] = "Discharge";

// Abrufen
string name = stagesById["YGow123"];  // name = "Admission"
```

### Was bedeutet `var`?

**Einfach erklärt:** "Computer, du weißt was das ist!"

Der Compiler erkennt automatisch den Typ.

**Diese beiden sind identisch:**
```csharp
Dictionary<string, string> stages = new Dictionary<string, string>();  // LANG
var stages = new Dictionary<string, string>();                         // KURZ
```

---

## 🔍 TryGetProperty (Zeile 51)

```csharp
if (root.TryGetProperty("programStages", out JsonElement stagesArray))
```

### Was macht `TryGetProperty`?

**Einfach erklärt:** "Gibt es dieses Feld? Wenn ja, gib es mir!"

**Aufbau:**
```csharp
if (root.TryGetProperty("feldName", out JsonElement variable))
//       ^                ^           ^
//       JSON-Objekt      Suche nach  Speichere hier
{
    // variable ist jetzt verfügbar!
}
```

### Was ist `out`?

**Einfach erklärt:** "Gibt einen Wert zurück UND als Parameter"

**Ohne `out`:**
```csharp
JsonElement stages = root.GetProperty("programStages");  // Exception wenn nicht vorhanden!
```

**Mit `out`:**
```csharp
if (TryGetProperty("programStages", out JsonElement stages))  // Kein Fehler, nur true/false
{
    // stages existiert nur hier drinnen
}
```

---

## 🔁 Foreach-Schleife (Zeile 54)

```csharp
foreach (JsonElement stage in stagesArray.EnumerateArray())
```

### Was ist `foreach`?

**Einfach erklärt:** "Für jedes Element in der Liste, tue..."

**Aufbau:**
```csharp
foreach (Typ elementName in sammlung)
//       ^    ^             ^
//       Was  Nenne es so   Woher
{
    // Mache etwas mit elementName
}
```

**Beispiel:**
```csharp
var zahlen = new List<int> { 1, 2, 3, 4, 5 };

foreach (int zahl in zahlen)
{
    Console.WriteLine(zahl);  // Gibt 1, 2, 3, 4, 5 aus
}
```

### Was macht `.EnumerateArray()`?

**Einfach erklärt:** Macht aus JSON-Array eine durchlaufbare Liste.

---

## 🔤 String mit ? (Zeile 56-57)

```csharp
string? id = stage.GetProperty("id").GetString();
string? name = stage.GetProperty("name").GetString();
```

### Was bedeutet `string?`?

**Einfach erklärt:** Text, der auch `null` (leer) sein kann.

**Ohne `?`:**
```csharp
string name;  // Muss immer Text haben
```

**Mit `?`:**
```csharp
string? name;  // Kann Text haben ODER null sein
```

### Was ist `null`?

**Einfach erklärt:** "Nichts", "leer", "nicht vorhanden"

**Beispiele:**
```csharp
string? name = null;           // Kein Wert
string? name = "Max";          // Hat Wert
string? name = "";             // Leerer Text (NICHT null!)
```

---

## ✅ If-Bedingung mit != null (Zeile 59)

```csharp
if (id != null && name != null)
```

### Was bedeutet `!=`?

**Einfach erklärt:** "nicht gleich"

**Vergleichs-Operatoren:**
```csharp
==  gleich
!=  nicht gleich
>   größer als
<   kleiner als
>=  größer oder gleich
<=  kleiner oder gleich
```

### Was bedeutet `&&`?

**Einfach erklärt:** "UND"

**Logische Operatoren:**
```csharp
&&  UND   (beide müssen wahr sein)
||  ODER  (einer muss wahr sein)
!   NICHT (kehrt um)
```

**Beispiel:**
```csharp
if (alter >= 18 && hatFuehrerschein)  // Beide Bedingungen!
if (wochenende || urlaub)             // Eine reicht!
if (!istGeschlossen)                  // Nicht geschlossen = offen
```

---

## 📥 Dictionary befüllen (Zeile 61)

```csharp
stagesById[id] = name;
```

### Was macht das?

**Einfach erklärt:** Fügt ein Schlüssel-Wert-Paar hinzu.

**Syntax:**
```csharp
dictionary[schluessel] = wert;
```

**Beispiel:**
```csharp
var telefonbuch = new Dictionary<string, string>();
telefonbuch["Max"] = "0123456789";
telefonbuch["Anna"] = "9876543210";

// Später abrufen:
string nummer = telefonbuch["Max"];  // "0123456789"
```

---

## 🎯 List erstellen (Zeile 71)

```csharp
var csvRows = new List<ProgramRuleCsvRow>();
```

### Was ist eine List?

**Einfach erklärt:** Eine dynamische Liste (kann wachsen).

**Syntax:**
```csharp
List<Typ> name = new List<Typ>();
```

**Beispiele:**
```csharp
List<int> zahlen = new List<int>();
List<string> namen = new List<string>();
List<ProgramRuleCsvRow> zeilen = new List<ProgramRuleCsvRow>();
```

**Nutzung:**
```csharp
zahlen.Add(5);        // Hinzufügen
zahlen.Add(10);
int erste = zahlen[0];  // Zugriff: erste = 5
int anzahl = zahlen.Count;  // Wie viele? anzahl = 2
```

---

## 🆕 Objekt erstellen (Zeile 103-107)

```csharp
csvRows.Add(new ProgramRuleCsvRow
{
    Name = name,
    Description = description,
    ProgramStage = programStageName
});
```

### Was passiert hier?

#### 1. `new ProgramRuleCsvRow`
**Einfach erklärt:** Erstellt ein neues Objekt von dieser Klasse.

#### 2. `{ Name = name, ... }`
**Einfach erklärt:** Objekt-Initialisierer (setzt Werte beim Erstellen).

**Langform:**
```csharp
ProgramRuleCsvRow row = new ProgramRuleCsvRow();
row.Name = name;
row.Description = description;
row.ProgramStage = programStageName;
csvRows.Add(row);
```

**Kurzform:**
```csharp
csvRows.Add(new ProgramRuleCsvRow
{
    Name = name,
    Description = description,
    ProgramStage = programStageName
});
```

---

## 📂 Verzeichnis erstellen (Zeile 115-118)

```csharp
string? outputDir = Path.GetDirectoryName(outputPath);
if (outputDir != null && !Directory.Exists(outputDir))
{
    Directory.CreateDirectory(outputDir);
}
```

### Was macht das?

**Schritt für Schritt:**

1. **`GetDirectoryName`:** Holt den Ordner-Teil aus dem Pfad
   ```csharp
   "C:\Projekt\Daten\file.csv" → "C:\Projekt\Daten"
   ```

2. **`Directory.Exists`:** Prüft ob Ordner existiert
   ```csharp
   true = Ordner existiert
   false = Ordner existiert nicht
   ```

3. **`Directory.CreateDirectory`:** Erstellt Ordner
   ```csharp
   Erstellt auch alle Unter-Ordner automatisch!
   ```

### Was bedeutet `!`?

**Einfach erklärt:** NICHT (kehrt true/false um)

```csharp
!Directory.Exists(outputDir)
^
NICHT existiert = existiert NICHT
```

---

## ⚙️ CsvConfiguration (Zeile 121-127)

```csharp
var csvConfig = new CsvConfiguration(CultureInfo.InvariantCulture)
{
    Encoding = Encoding.UTF8
};
```

### Was ist eine Configuration?

**Einfach erklärt:** Einstellungen für das CSV-Schreiben.

**Was wird eingestellt:**
- `CultureInfo.InvariantCulture` = Nutze internationale Formate (nicht deutsch/englisch spezifisch)
- `Encoding = UTF8` = Nutze UTF-8 für Umlaute (ä, ö, ü, ß)

---

## ✍️ CSV schreiben (Zeile 130-135)

```csharp
using (var writer = new StreamWriter(outputPath, false, Encoding.UTF8))
using (var csv = new CsvWriter(writer, csvConfig))
{
    csv.WriteRecords(csvRows);
}
```

### Was passiert hier?

#### 1. `StreamWriter`
**Einfach erklärt:** Schreibt Text in eine Datei.

**Parameter:**
- `outputPath` = Wo soll geschrieben werden?
- `false` = Überschreibe Datei (nicht anhängen)
- `Encoding.UTF8` = Nutze UTF-8

#### 2. `CsvWriter`
**Einfach erklärt:** Schreibt Objekte als CSV.

#### 3. `WriteRecords`
**Einfach erklärt:** Schreibt automatisch Header + alle Zeilen!

**Magisch:** CsvHelper schaut sich die Klasse an und erstellt automatisch:
```csv
Name,Description,ProgramStage
Rule1,Validates date,Admission
Rule2,Checks value,Discharge
```

---

## ❌ Exception Handling (Zeile 144-149)

```csharp
catch (Exception ex)
{
    Console.Error.WriteLine($"FEHLER: {ex.Message}");
    Console.Error.WriteLine(ex.StackTrace);
    Environment.Exit(1);
}
```

### Was macht das?

#### `catch (Exception ex)`
**Einfach erklärt:** Fängt JEDEN Fehler ab und nennt ihn `ex`.

#### `Console.Error.WriteLine`
**Einfach erklärt:** Schreibt in den Fehler-Stream (rot in manchen Konsolen).

#### `ex.Message`
**Einfach erklärt:** Kurze Fehlerbeschreibung.
```
"Datei nicht gefunden"
```

#### `ex.StackTrace`
**Einfach erklärt:** Wo genau ist der Fehler passiert?
```
at Program.Main() in Program.cs:line 45
```

#### `Environment.Exit(1)`
**Einfach erklärt:** Beende Programm mit Fehlercode.
- `0` = Alles OK ✅
- `1` = Fehler ❌

---

## 🏗️ Klassen-Definition (Zeile 158-164)

```csharp
public class ProgramRuleCsvRow
{
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public string ProgramStage { get; set; } = "";
}
```

### Was ist das?

**Einfach erklärt:** Ein Bauplan für ein Objekt.

**Analogie:** Formular
```
┌─────────────────────────┐
│ Name:        [______]   │
│ Description: [______]   │
│ ProgramStage:[______]   │
└─────────────────────────┘
```

### Was bedeutet `public`?

**Einfach erklärt:** Jeder kann das sehen und nutzen.

**Sichtbarkeiten:**
```csharp
public    = Jeder kann zugreifen
private   = Nur diese Klasse
internal  = Nur dieses Projekt
protected = Nur Klasse + Unterklassen
```

### Was ist `{ get; set; }`?

**Einfach erklärt:** Macht die Variable les- und schreibbar.

**Beispiele:**
```csharp
public string Name { get; set; }        // Lesen UND Schreiben
public string Name { get; }             // Nur Lesen
public string Name { get; private set; } // Öffentlich lesen, privat schreiben
```

### Was bedeutet `= ""`?

**Einfach erklärt:** Standardwert (wenn nichts gesetzt wird).

```csharp
var row = new ProgramRuleCsvRow();
// row.Name ist jetzt "" (leerer String) statt null
```

---

## 🎓 Zusammenfassung - Programmablauf

### **Schritt für Schritt:**

1. **Start:** `Main` wird aufgerufen
2. **Pfade:** Lege fest, wo JSON-Datei ist und wo CSV hin soll
3. **Lesen:** Lese gesamte JSON-Datei
4. **Parsen:** Mache aus Text eine Struktur
5. **Lookup:** Erstelle Dictionary mit Stage-IDs → Stage-Namen
6. **Verarbeiten:** Gehe durch alle programRules und erstelle CSV-Zeilen
7. **Schreiben:** Schreibe alle Zeilen in CSV-Datei
8. **Fertig:** Zeige Erfolgsmeldung

### **Bei Fehler:**
- Fange Fehler ab
- Zeige Fehlermeldung
- Beende sauber mit Fehlercode

---

## 💡 Wichtige Konzepte nochmal

| Konzept | Was ist das? | Beispiel |
|---------|--------------|----------|
| **Klasse** | Bauplan für Objekte | `class Auto` |
| **Objekt** | Konkretes Ding | `var meinAuto = new Auto()` |
| **Methode** | Funktion in einer Klasse | `void Fahren()` |
| **Property** | Variable in einer Klasse | `string Name { get; set; }` |
| **Variable** | Speicherplatz für Wert | `int alter = 30;` |
| **String** | Text | `"Hallo Welt"` |
| **Int** | Ganze Zahl | `42` |
| **Bool** | Ja/Nein | `true` oder `false` |
| **Null** | Nichts, leer | `null` |
| **List** | Dynamische Liste | `List<int>` |
| **Dictionary** | Schlüssel-Wert-Paare | `Dictionary<string, string>` |

---

## ❓ Häufige Fragen

### "Warum so viele Typen angeben?"
C# ist **streng typisiert** = Compiler prüft alles VOR der Ausführung → Weniger Fehler!

### "Was ist der Unterschied zwischen Klasse und Objekt?"
- **Klasse** = Bauplan (einmal definiert)
- **Objekt** = Konkretes Ding (viele davon erstellen)

Analogie: 
- Kuchen-Rezept = Klasse
- Echter Kuchen = Objekt

### "Warum `var` statt konkreten Typ?"
Macht Code kürzer und lesbarer. Compiler weiß trotzdem den genauen Typ!

### "Was bedeuten die `{ }` überall?"
Geschweifte Klammern gruppieren Code:
- Klassen-Körper
- Methoden-Körper
- If/For/While-Blöcke

---

**Das war's! Du hast jetzt alles grundlegend verstanden! 🎉**
