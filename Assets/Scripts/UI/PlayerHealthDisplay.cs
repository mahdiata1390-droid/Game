using UnityEngine;
using UnityEngine.UI;

public sealed class PlayerHealthDisplay : MonoBehaviour
{
    [SerializeField] private Health target;
    [SerializeField] private Image fill;
    [SerializeField] private Text valueLabel;

    public void Configure(Health health, Image fillImage, Text label)
    {
        target = health;
        fill = fillImage;
        valueLabel = label;
        Refresh();
    }

    private void Update() { Refresh(); }

    private void Refresh()
    {
        if (target == null || fill == null) return;
        fill.fillAmount = target.Max > 0 ? (float)target.Current / target.Max : 0f;
        if (valueLabel != null) valueLabel.text = "HP " + target.Current + " / " + target.Max;
    }
}
