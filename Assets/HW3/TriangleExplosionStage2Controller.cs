using System;
using System.Runtime.InteropServices;
using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class TriangleExplosionStage2Controller : MonoBehaviour
{
    [SerializeField] private ComputeShader computeShader;
    [SerializeField] private Material renderMaterial;

    [Header("Explosion")]
    [SerializeField] private float lifetime = 2.5f;
    [SerializeField] private float minSpeed = 1.5f;
    [SerializeField] private float maxSpeed = 4.0f;
    [SerializeField] private Vector3 baseAcceleration = new Vector3(0f, -1.5f, 0f);

    private const string BufferName = "_TriangleData";
    private const int ThreadGroupSize = 64;

    [StructLayout(LayoutKind.Sequential)]
    private struct TriangleData
    {
        public Vector4 offsetLife;   // xyz = offset, w = lifetime
        public Vector4 velocityAge;  // xyz = velocity, w = age
        public Vector4 accelActive;  // xyz = acceleration, w = active (1 or 0)
    }

    private Mesh mesh;
    private ComputeBuffer triangleBuffer;
    private TriangleData[] triangleData;
    private int triangleCount;
    private int kernelIndex;

    private void Start()
    {
        mesh = GetComponent<MeshFilter>().sharedMesh;

        if (mesh == null)
        {
            Debug.LogError("TriangleExplosionStage2Controller: No mesh found.");
            enabled = false;
            return;
        }

        int[] triangles = mesh.triangles;
        triangleCount = triangles.Length / 3;

        if (triangleCount <= 0)
        {
            Debug.LogError("TriangleExplosionStage2Controller: Mesh has no triangles.");
            enabled = false;
            return;
        }

        triangleData = new TriangleData[triangleCount];

        for (int i = 0; i < triangleCount; i++)
        {
            Vector3 randomDirection = UnityEngine.Random.onUnitSphere;
            float speed = UnityEngine.Random.Range(minSpeed, maxSpeed);
            Vector3 velocity = randomDirection * speed;

            triangleData[i] = new TriangleData
            {
                offsetLife = new Vector4(0f, 0f, 0f, lifetime),
                velocityAge = new Vector4(velocity.x, velocity.y, velocity.z, 0f),
                accelActive = new Vector4(baseAcceleration.x, baseAcceleration.y, baseAcceleration.z, 1f)
            };
        }

        triangleBuffer = new ComputeBuffer(triangleCount, Marshal.SizeOf<TriangleData>());
        triangleBuffer.SetData(triangleData);

        kernelIndex = computeShader.FindKernel("CSMain");

        computeShader.SetInt("_TriangleCount", triangleCount);
        computeShader.SetBuffer(kernelIndex, BufferName, triangleBuffer);

        var renderer = GetComponent<MeshRenderer>();
        renderer.material = new Material(renderMaterial);
        renderer.material.SetBuffer(BufferName, triangleBuffer);
    }

    private void Update()
    {
        if (triangleBuffer == null)
            return;

        computeShader.SetFloat("_DeltaTime", Time.deltaTime);
        computeShader.SetBuffer(kernelIndex, BufferName, triangleBuffer);

        int groups = Mathf.CeilToInt(triangleCount / (float)ThreadGroupSize);
        computeShader.Dispatch(kernelIndex, groups, 1, 1);
    }

    private void OnDestroy()
    {
        if (triangleBuffer != null)
        {
            triangleBuffer.Release();
            triangleBuffer = null;
        }
    }
}