using System.Security.Cryptography;
using System.Text;

namespace Budgetism.Api;

public static class PlanningProtection
{
    public static byte[] ReadKey()
    {
        var path = Environment.GetEnvironmentVariable("PLANNING_KEY_FILE");
        if (string.IsNullOrWhiteSpace(path)) throw new InvalidOperationException("Planning key unavailable.");
        var key = Convert.FromBase64String(File.ReadAllText(path).Trim());
        if (key.Length != 32) throw new InvalidOperationException("Planning key unavailable.");
        return key;
    }
    public static string Seal(string text, byte[] key, Guid owner, string purpose)
    {
        var nonce = RandomNumberGenerator.GetBytes(12); var plain = Encoding.UTF8.GetBytes(text);
        var cipher = new byte[plain.Length]; var tag = new byte[16];
        using var aes = new AesGcm(key, 16);
        aes.Encrypt(nonce, plain, cipher, tag, Encoding.UTF8.GetBytes(owner + ":" + purpose));
        CryptographicOperations.ZeroMemory(plain);
        return "v1:" + Convert.ToBase64String(nonce.Concat(tag).Concat(cipher).ToArray());
    }
    public static string Open(string text, byte[] key, Guid owner, string purpose)
    {
        if (!text.StartsWith("v1:", StringComparison.Ordinal)) throw new CryptographicException("Invalid protected planning record.");
        var value = Convert.FromBase64String(text[3..]);
        if (value.Length < 28) throw new CryptographicException("Invalid protected planning record.");
        var plain = new byte[value.Length - 28];
        using var aes = new AesGcm(key, 16);
        aes.Decrypt(value.AsSpan(0, 12), value.AsSpan(28), value.AsSpan(12, 16), plain, Encoding.UTF8.GetBytes(owner + ":" + purpose));
        var result = Encoding.UTF8.GetString(plain); CryptographicOperations.ZeroMemory(plain); return result;
    }
}
