/*
Maintainer: Shoter
    Dispersion radius of rebel mortar fire missions, from the rebel training level (skillFIA).
    Untrained rebels (level 1) scatter rounds up to 100 m from the aim point, fully trained ones (level 20) up to 25 m.
    The curve is quadratic, so the first trainings cut the dispersion the most and later ones less.

Arguments:
    None

Return Value:
    <NUMBER> Dispersion radius in metres

Scope: Any
Environment: Any
Public: No

Example:
    private _dispersion = call A3A_fnc_rebelMortarDispersion;
*/

#define DISPERSION_UNTRAINED 100
#define DISPERSION_TRAINED 25
#define TRAINING_MIN 1
#define TRAINING_MAX 20

private _training = (missionNamespace getVariable ["skillFIA", TRAINING_MIN]) max TRAINING_MIN min TRAINING_MAX;
private _untrainedShare = (TRAINING_MAX - _training) / (TRAINING_MAX - TRAINING_MIN);

DISPERSION_TRAINED + (DISPERSION_UNTRAINED - DISPERSION_TRAINED) * _untrainedShare ^ 2
