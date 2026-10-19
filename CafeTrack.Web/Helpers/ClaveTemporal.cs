using System.Security.Cryptography;

namespace CafeTrack.Web.Helpers;

/// <summary>
/// Genera las contraseñas temporales que el administrador entrega al usuario.
/// Son legibles para dictarlas por teléfono: sin caracteres que se confundan
/// (0 y O, 1 y l) y en bloques separados por guion.
/// </summary>
public static class ClaveTemporal
{
    private const string Alfabeto = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

    /// <summary>Devuelve algo como <c>Cafe-7K3M-R9TX</c>.</summary>
    public static string Generar()
    {
        return $"Cafe-{Bloque()}-{Bloque()}";

        static string Bloque()
        {
            var letras = new char[4];
            for (var i = 0; i < letras.Length; i++)
            {
                letras[i] = Alfabeto[RandomNumberGenerator.GetInt32(Alfabeto.Length)];
            }

            return new string(letras);
        }
    }
}
