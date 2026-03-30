
  class ZoneStabilizerState {
    int currentZone = 1;
    int candidateZone = 1;
    int candidateCount = 0;
    bool initialized = false;
  }

  class ZoneStabilizer {
    final int dwellSamples;

    ZoneStabilizer({required this.dwellSamples});


    int update(ZoneStabilizerState s, int newZone) {
      if (!s.initialized) {
        s.currentZone = newZone;
        s.candidateZone = newZone;
        s.candidateCount = 0;
        s.initialized = true;
        return s.currentZone;
      }

      if (newZone == s.currentZone) {

        s.candidateZone = s.currentZone;
        s.candidateCount = 0;
        return s.currentZone;
      }


      if (newZone != s.candidateZone) {

        s.candidateZone = newZone;
        s.candidateCount = 1;
        return s.currentZone;
      }


      s.candidateCount += 1;
      if (s.candidateCount >= dwellSamples) {
        s.currentZone = s.candidateZone;
        s.candidateCount = 0;
      }

      return s.currentZone;
    }

    void reset(ZoneStabilizerState s) {
      s.currentZone = 1;
      s.candidateZone = 1;
      s.candidateCount = 0;
      s.initialized = false;
    }
  }
