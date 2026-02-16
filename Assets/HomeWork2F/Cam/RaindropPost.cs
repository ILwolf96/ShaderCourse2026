using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class RaindropPost : MonoBehaviour
{
    public Material postMaterial;

    [Range(0f, 1f)] public float RainIntensity = 0.5f;
    [Range(0f, 2f)] public float DistortionStrength = 0.5f;
    [Range(0.1f, 3f)] public float DropSize = 1.0f;
    [Tooltip("1 = keep droplet positions fixed, 0 = droplets move over time")]
    [Range(0f, 1f)] public float StaticDrops = 1.0f;
    [Range(0f, 1f)] public float DarkenMin = 0.75f;

    void OnValidate()
    {
        ApplyToMaterial();
    }

    void Update()
    {
        ApplyToMaterial();
    }

    void ApplyToMaterial()
    {
        if (postMaterial == null) return;
        postMaterial.SetFloat("_RainIntensity", RainIntensity);
        postMaterial.SetFloat("_DistortionStrength", DistortionStrength);
        postMaterial.SetFloat("_DropSize", DropSize);
        postMaterial.SetFloat("_StaticDrops", StaticDrops);
        postMaterial.SetFloat("_DarkenMin", DarkenMin);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (postMaterial == null)
        {
            Graphics.Blit(src, dest);
            return;
        }
        // Graphics.Blit will bind 'src' to _MainTex automatically
        Graphics.Blit(src, dest, postMaterial);
    }
}
