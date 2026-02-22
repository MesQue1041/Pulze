
  class ZoneStabilizerState {
    int currentZone = 1;
    int candidateZone = 1;
    int candidateCount = 0;
    bool initialized = false;
  }

  class ZoneStabilizer {
    final int dwellSamples;

    ZoneStabilizer({required this.dwellSamples});

    /// Feed raw zone (1..5) and get stabilized zone (1..5).
    int update(ZoneStabilizerState s, int newZone) {
      if (!s.initialized) {
        s.currentZone = newZone;
        s.candidateZone = newZone;
        s.candidateCount = 0;
        s.initialized = true;
        return s.currentZone;
      }

      if (newZone == s.currentZone) {
        // reset candidate if we are back to current
        s.candidateZone = s.currentZone;
        s.candidateCount = 0;
        return s.currentZone;
      }

      // new zone differs from current
      if (newZone != s.candidateZone) {
        // start tracking a new candidate
        s.candidateZone = newZone;
        s.candidateCount = 1;
        return s.currentZone;
      }

      // continuing same candidate
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
