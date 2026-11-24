part of 'fit_state.dart';

mixin GymMinState on FitCore, SettingsState, TimelineState, StepsState, RecoveryState, NutritionState, AwardsState {
  @override
  bool get nutritionBeta => GymMin.nutrition && super.nutritionBeta;
  @override
  set nutritionBeta(bool on) {
    if (GymMin.nutrition) super.nutritionBeta = on;
  }

  @override
  bool get recoveryOn => GymMin.recovery && super.recoveryOn;
  @override
  set recoveryOn(bool on) {
    if (GymMin.recovery) super.recoveryOn = on;
  }

  @override
  bool get passOn => GymMin.gymPass && super.passOn;
  @override
  set passOn(bool on) {
    if (GymMin.gymPass) super.passOn = on;
  }

  @override
  bool get showMiniBody => GymMin.muscleMap && super.showMiniBody;
  @override
  set showMiniBody(bool on) {
    if (GymMin.muscleMap) super.showMiniBody = on;
  }

  @override
  bool get showRecommended => GymMin.suggested && super.showRecommended;
  @override
  set showRecommended(bool on) {
    if (GymMin.suggested) super.showRecommended = on;
  }

  @override
  bool get gamification => GymMin.medals && super.gamification;
  @override
  set gamification(bool on) {
    if (GymMin.medals) super.gamification = on;
  }

  @override
  bool get stepsOn => GymMin.steps && super.stepsOn;
  @override
  set stepsOn(bool on) {
    if (GymMin.steps) super.stepsOn = on;
  }

  @override
  AwardId? get nextCelebration => GymMin.medals ? super.nextCelebration : null;

  @override
  bool get photoDue => GymMin.photos && super.photoDue;
}
