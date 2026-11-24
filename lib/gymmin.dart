class GymMin {
  static bool photos = false;
  static bool measurements = false;
  static bool muscleMap = false;
  static bool nutrition = false;
  static bool recovery = false;
  static bool medals = false;
  static bool healthConnect = false;
  static bool steps = false;
  static bool gymPass = false;
  static bool sharing = false;
  static bool nfc = false;
  static bool watch = false;
  static bool suggested = false;
  static bool bodyComposition = false;
  static bool aiRoutine = false;
  static bool languages = false;

  static void setAll(bool on) {
    photos = measurements = muscleMap = nutrition = recovery = medals = healthConnect = steps = on;
    gymPass = sharing = nfc = watch = suggested = bodyComposition = aiRoutine = languages = on;
  }
}
