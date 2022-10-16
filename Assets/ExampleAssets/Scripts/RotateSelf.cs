using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateSelf : MonoBehaviour
{

    public Vector3 rotateAxis = Vector3.up;
    public float rotateSpeed = 180f;
    public Space space = Space.Self;

    void Update()
    {
        transform.Rotate(rotateAxis, rotateSpeed * Time.deltaTime, space);
    }

}
