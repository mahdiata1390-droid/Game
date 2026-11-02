using System.Collections;
using UnityEngine;
using UnityEngine.UI;

public sealed class PrototypeStatusDisplay : MonoBehaviour
{
    private static PrototypeStatusDisplay instance;
    private Text label;
    private Coroutine clearRoutine;

    public void Configure(Text target)
    {
        instance = this;
        label = target;
        label.text = string.Empty;
    }

    public static void Show(string message)
    {
        if (instance != null) instance.ShowMessage(message);
    }

    private void ShowMessage(string message)
    {
        if (label == null) return;
        label.text = message;
        if (clearRoutine != null) StopCoroutine(clearRoutine);
        clearRoutine = StartCoroutine(ClearAfterDelay());
    }

    private IEnumerator ClearAfterDelay()
    {
        yield return new WaitForSeconds(2.4f);
        if (label != null) label.text = string.Empty;
        clearRoutine = null;
    }

    private void OnDestroy()
    {
        if (instance == this) instance = null;
    }
}
