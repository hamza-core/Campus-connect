using System.Text.RegularExpressions;

namespace CampusConnect.Api.Chat;

public record KnowledgeChunk(string Title, string Text, bool StaffOnly = false);
public record ScoredChunk(KnowledgeChunk Chunk, double Score);

/// <summary>In-memory BM25 index over the Markdown files in <c>knowledge/</c>. No database, no external service.</summary>
public sealed partial class KnowledgeIndex
{
    private const double K1 = 1.5, B = 0.5;
    private readonly List<KnowledgeChunk> chunks;
    private readonly List<Dictionary<string, int>> termCounts;
    private readonly List<int> lengths;
    private readonly Dictionary<string, int> docFrequency = [];
    private readonly double averageLength;

    public KnowledgeIndex(IEnumerable<KnowledgeChunk> source)
    {
        chunks = source.ToList();
        termCounts = chunks.Select(c => Count(Tokenize(c.Title + " " + c.Title + " " + c.Title + " " + c.Text))).ToList();
        lengths = termCounts.Select(t => t.Values.Sum()).ToList();
        averageLength = lengths.Count == 0 ? 0 : lengths.Average();
        foreach (var terms in termCounts)
            foreach (var term in terms.Keys)
                docFrequency[term] = docFrequency.GetValueOrDefault(term) + 1;
    }

    public int Count() => chunks.Count;

    public static KnowledgeIndex FromDirectory(string directory)
    {
        if (!Directory.Exists(directory)) return new KnowledgeIndex([]);
        var all = new List<KnowledgeChunk>();
        foreach (var file in Directory.GetFiles(directory, "*.md").OrderBy(f => f, StringComparer.Ordinal))
        {
            if (Path.GetFileName(file).Equals("README.md", StringComparison.OrdinalIgnoreCase)) continue;
            var staffOnly = Path.GetFileName(file).StartsWith("staff-", StringComparison.OrdinalIgnoreCase);
            all.AddRange(Chunk(File.ReadAllText(file)).Select(c => c with { StaffOnly = staffOnly }));
        }
        return new KnowledgeIndex(all);
    }

    /// <summary>Splits Markdown into one chunk per <c>##</c> section (large sections are split by paragraph).</summary>
    public static IEnumerable<KnowledgeChunk> Chunk(string markdown, int maxChars = 900)
    {
        var document = "";
        var heading = "";
        var body = new List<string>();
        var result = new List<KnowledgeChunk>();
        void Flush()
        {
            var text = string.Join("\n", body).Trim();
            body.Clear();
            if (text.Length == 0) return;
            var title = heading.Length > 0 ? heading : document;
            var buffer = "";
            foreach (var paragraph in text.Split("\n\n", StringSplitOptions.RemoveEmptyEntries))
            {
                if (buffer.Length > 0 && buffer.Length + paragraph.Length > maxChars)
                {
                    result.Add(new KnowledgeChunk(title, buffer.Trim()));
                    buffer = "";
                }
                buffer += paragraph + "\n\n";
            }
            if (buffer.Trim().Length > 0) result.Add(new KnowledgeChunk(title, buffer.Trim()));
        }
        foreach (var line in markdown.Replace("\r\n", "\n").Split('\n'))
        {
            if (line.StartsWith("## ")) { Flush(); heading = line[3..].Trim(); }
            else if (line.StartsWith("# ")) { Flush(); document = line[2..].Trim(); heading = ""; }
            else body.Add(line);
        }
        Flush();
        return result;
    }

    public IReadOnlyList<ScoredChunk> Search(string query, int top = 4, bool includeStaff = true)
    {
        var queryTerms = Tokenize(query).Distinct().ToList();
        if (queryTerms.Count == 0 || chunks.Count == 0) return [];
        var scored = new List<ScoredChunk>();
        for (var i = 0; i < chunks.Count; i++)
        {
            if (chunks[i].StaffOnly && !includeStaff) continue;
            double score = 0;
            foreach (var term in queryTerms)
            {
                if (!termCounts[i].TryGetValue(term, out var tf)) continue;
                var df = docFrequency[term];
                var idf = Math.Log(1 + (chunks.Count - df + 0.5) / (df + 0.5));
                score += idf * tf * (K1 + 1) / (tf + K1 * (1 - B + B * lengths[i] / Math.Max(1, averageLength)));
            }
            if (score > 0) scored.Add(new ScoredChunk(chunks[i], score));
        }
        return scored.OrderByDescending(s => s.Score).Take(top).ToList();
    }

    private static Dictionary<string, int> Count(IEnumerable<string> tokens)
    {
        var counts = new Dictionary<string, int>();
        foreach (var token in tokens) counts[token] = counts.GetValueOrDefault(token) + 1;
        return counts;
    }

    private static readonly HashSet<string> Stop = ["the", "a", "an", "is", "are", "to", "of", "in", "on", "and", "or", "for", "my", "me", "i", "it", "do", "does", "can", "how", "what", "when", "if", "be", "you", "with", "at", "by", "this", "that"];

    public static IEnumerable<string> Tokenize(string text) =>
        Word().Matches(text.ToLowerInvariant()).Select(m => Stem(m.Value)).Where(t => t.Length > 1 && !Stop.Contains(t));

    private static string Stem(string word) =>
        word.Length > 4 && word.EndsWith("ies") ? word[..^3] + "y"
        : word.Length > 4 && word.EndsWith("es") ? word[..^2]
        : word.Length > 3 && word.EndsWith('s') ? word[..^1]
        : word;

    [GeneratedRegex("[a-z0-9]+")] private static partial Regex Word();
}
