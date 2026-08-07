//+------------------------------------------------------------------+
//| HorizonProbe.mq5 — THE ORACLE CEILING, MEASURED PER HORIZON     |
//|                                                                  |
//| ⚠️ THIS IS A SCRIPT, NOT AN EXPERT ADVISOR: it trades NOTHING,   |
//| it opens NOTHING, it reads no EA parameter. Same spirit as an    |
//| instrument passport — a STANDALONE, DETACHABLE diagnostic tool:  |
//| no #include, no external dependency.                             |
//| It can be copied as is into any terminal.                        |
//|                                                                  |
//| WHY IT EXISTS: the oracle ceiling per horizon is usually         |
//| ESTIMATED — square-root-of-time scaling plus a Gaussian          |
//| approximation. Gold has fat tails, and a Gaussian underestimates |
//| precisely what matters: the large moves.                         |
//| This script REPLACES the calculation with a MEASUREMENT: every   |
//| rolling window, the real observed cost, no assumption.           |
//|                                                                  |
//| ── WHAT IT PUBLISHES, HORIZON BY HORIZON (H in MINUTES) ───────   |
//| • CEILING (median cost) = share of windows where the move        |
//|   |close(t+H) − close(t)| EXCEEDS the median round-trip cost.    |
//| • CEILING (window cost) = the same count, but each window judged |
//|   at the spread ACTUALLY observed at its entry.                  |
//|   THE GAP BETWEEN THE TWO QUANTIFIES the bias of a constant      |
//|   cost: the spread on gold explodes when the move is large —     |
//|   judging a news minute at the toll of a quiet hour OVERSTATES   |
//|   the ceiling (the per-window measurement was available in the   |
//|   same table, so it is no longer assumed).                       |
//| • ★ ORACLE EXPECTANCY = MEAN amplitude − cost. THIS IS THE       |
//|   PROFITABILITY JUDGE for a perfect direction: an oracle that    |
//|   trades every window earns (|d| − cost) each time, so it is     |
//|   profitable IFF mean(|d|) > cost. ⚠️ THIS IS NOT the CEILING:   |
//|   the ceiling counts individually winning windows, and with fat  |
//|   tails (median ≪ mean) an oracle can be widely profitable with  |
//|   fewer than half of the windows above the toll (v1.01 review:   |
//|   a verdict drawn from the ceiling alone was systematically      |
//|   PESSIMISTIC — on gold, that is, precisely where this script    |
//|   is useful).                                                     |
//| • BREAK-EVEN THRESHOLD = 0.5 + cost / (2 × mean amplitude): the  |
//|   directional hit rate required to cover the cost.               |
//|   It compares to 100 % (an oracle's rate): above 100 %,          |
//|   UNREACHABLE even when perfect.                                 |
//| • MARGIN = CEILING − THRESHOLD, published for the record and     |
//|   kept as is — ⚠️ BUT it is the DIFFERENCE OF TWO RATES OF       |
//|   DIFFERENT NATURES (a share of windows minus a required hit     |
//|   rate): read it as an indicator, NEVER as the profitability     |
//|   verdict. The verdict is the EXPECTANCY above.                  |
//| • Windows kept, NON-OVERLAPPING equivalent (≈ used/H — rolling   |
//|   windows are NOT independent draws), and the windows discarded. |
//|                                                                  |
//| ── THE COST ───────────────────────────────────────────────────  |
//| The SPREAD OBSERVED IN THE HISTORY (median of MqlRates.spread    |
//| over the bars read), NEVER a constant nor the current spread.    |
//| The distribution is published (min/median/p90/max), the share of |
//| the MODAL value, and the medians of the two chronological        |
//| HALVES: a fixed spread, or a REGIME CHANGE inside the history,   |
//| becomes visible — a spread-based rule run on a fixed spread      |
//| would have tested nothing, and nobody would have noticed. Bars   |
//| with a spread of 0 (imported history, custom symbol) are COUNTED |
//| and EXCLUDED from the median, and that is said.                  |
//| ⚠️ MqlRates.spread is the spread RECORDED by the terminal for    |
//| the bar (its exact sampling instant is not documented): the      |
//| source is stated here, never assumed.                            |
//| ⚠️ COMMISSION and SLIPPAGE are NOT included — the first has      |
//| never been measured on this account, the second is not           |
//| measurable from bar history. The published cost is therefore a   |
//| FLOOR, and any CEILING an OPTIMISTIC upper bound.                |
//|                                                                  |
//| ── THE DISCARDED WINDOWS ──────────────────────────────────────  |
//| A window is kept ONLY if (time[t+H] − time[t]) == H × 60         |
//| exactly: that discards, in one test, both pauses AND missing     |
//| minutes (a window with absent bars does not last H minutes, it   |
//| would measure something else). The two causes are classified on  |
//| THE LARGEST GAP between two consecutive bars INSIDE the window   |
//| (and not on the cumulated excess). ⚠️ The script measures a      |
//| DURATION, it does not observe the CAUSE: a weekend and a 30-min  |
//| data hole are indistinguishable, so the columns are named        |
//| "gap >= 30 min" / "gap < 30 min".                                |
//| ⚠️ BIAS ASSUMED AND PUBLISHED: discarding windows with a missing |
//| minute preferentially removes the QUIET stretches => the         |
//| measured amplitude and ceiling are those of the most active      |
//| subset. The RETENTION RATE is published per horizon so that the  |
//| bias can be quantified.                                          |
//|                                                                  |
//| ── THE DATE BOUNDS (v1.02) ────────────────────────────────────  |
//| MEASURED REASON: a first run had read only 50 005 M1 bars —      |
//| seven weeks, not the intended window. And even with the full     |
//| history, a single measurement over several years would AVERAGE   |
//| TWO REGIMES: over roughly two years, the median amplitude per    |
//| minute went from about 24 to 74 points while the price doubled.  |
//| This script therefore separates its windows by period.           |
//|                                                                  |
//| SEMANTICS: a rolling window is kept only if ITS OPENING t falls  |
//| inside [HP_DateFrom, HP_DateTo].                                 |
//| ⚠️ THE WINDOW IS ALLOWED TO END AFTER HP_DateTo — and that is    |
//| DELIBERATE: bounding the end as well would truncate long         |
//| horizons UNEQUALLY (H=120 would lose 2 h more than H=1) and the  |
//| table columns would no longer be comparable to each other.       |
//| Assumed consequence: the last windows of a period read bars      |
//| later than To. It is said here AND in the output line.           |
//| THE COST IS RECOMPUTED OVER THE PERIOD (distribution, regime,    |
//| zero-spread bars) — the spread of one year is not the spread of  |
//| the next, and that is the whole point of this version. The       |
//| window count and the retention rate are period-relative too.     |
//| With the defaults (both dates at 1970), ALL the history read is  |
//| kept: the table is the v1.01 one, bit for bit.                   |
//|                                                                  |
//| HORIZONS IN MINUTES => THE MEASUREMENT IS MADE ON M1, whatever   |
//| the chart timeframe (only the SYMBOL is taken from the chart).   |
//| ⚠️ THIS SCRIPT MEASURES, IT OPTIMISES NOTHING.                   |
//+------------------------------------------------------------------+
#property copyright "Javad Razavi — The Solution Maker"
#property link      "https://javadrazavi.fr"
#property version   "1.02"
#property description "Measures, per horizon, the share of rolling windows whose move exceeds the"
#property description "observed round-trip cost — no distribution assumption, no optimisation."
#property script_show_inputs

input double HP_Lots     = 0.01;                    // Reference size used to convert points into account currency. Display convention only. Affects NO ratio — only the money column.
input int    HP_MaxBars  = 500000;                  // Upper bound on the M1 history read. Insufficient history = EXPLICIT REFUSAL, never a silently truncated measurement.
input string HP_Horizons = "1,2,5,10,15,30,60,120"; // Horizons in MINUTES, separated by COMMAS, integers only. Any malformed or duplicate token = EXPLICIT REFUSAL.
input datetime HP_DateFrom = D'1970.01.01';         // Start of the measured period (1970 = ALL the history read, bit-for-bit v1.01 behaviour). A window is kept only if ITS OPENING falls inside [From, To].
input datetime HP_DateTo   = D'1970.01.01';         // End of the measured period (1970 = ALL the history read). ⚠️ It bounds the OPENING of the windows, NOT their end: a window may end after To (otherwise H=120 would lose 2 h more than H=1 and the columns would no longer be comparable).

//--- Minimum independent sample below which a horizon is declared NOT
//    CONCLUSIVE. ⚠️ Applied to the NON-OVERLAPPING equivalent (used/H), not to
//    the raw count: rolling windows share H−1 minutes out of H and are not
//    independent draws.
#define HP_MIN_WINDOWS   10000
//--- Pause convention: >= 30 min between two M1 bars.
#define HP_PAUSE_SECONDS 1800
#define HP_MAX_HORIZONS  32
//--- Below this retention rate, the selection bias is named on the line.
#define HP_MIN_RETENTION 0.90

//+------------------------------------------------------------------+
//| EXPLICIT REFUSAL — written here so that the script stays         |
//| DETACHABLE (no external include).                                |
//+------------------------------------------------------------------+
void HP_Reject(const string param, const string value, const string expected, const string hint)
  {
   PrintFormat("SB [HORIZON] ⛔ REFUSED : %s = %s — expected %s. %s", param, value, expected, hint);
  }

//--- Quantile of an ALREADY SORTED array (linear interpolation).
double HP_Quantile(const double &sorted[], const double q)
  {
   const int n = ArraySize(sorted);
   if(n <= 0)
      return 0.0;
   if(n == 1)
      return sorted[0];
   const double pos = q * (n - 1);
   const int    lo  = (int)MathFloor(pos);
   const int    hi  = (int)MathMin((double)(n - 1), lo + 1);
   const double f   = pos - lo;
   return sorted[lo] * (1.0 - f) + sorted[hi] * f;
  }

//--- Checked ArrayResize: an allocation failure must produce an EXPLICIT
//    REFUSAL, never an "array out of range".
bool HP_Resize(double &arr[], const int n, const string what)
  {
   if(ArrayResize(arr, n) == n)
      return true;
   HP_Reject("HP_MaxBars", IntegerToString(n), "an array size that fits in memory",
             "Allocation refused for \"" + what + "\" — lower HP_MaxBars.");
   return false;
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   //================================================================
   //  0. VALIDATION — explicit refusals, never silence.
   //================================================================
   if(HP_Lots <= 0.0)
     {
      HP_Reject("HP_Lots", DoubleToString(HP_Lots, 2), "> 0",
                "Reference size for the money column (no ratio depends on it).");
      return;
     }
   if(HP_MaxBars < 1000)
     {
      HP_Reject("HP_MaxBars", IntegerToString(HP_MaxBars), ">= 1000",
                "Below 1000 M1 bars, no horizon can return a readable sample.");
      return;
     }
   string parts[];
   const int nParts = StringSplit(HP_Horizons, ',', parts);
   if(nParts <= 0)
     {
      HP_Reject("HP_Horizons", "\"" + HP_Horizons + "\"", "integers separated by COMMAS",
                "Example: \"1,2,5,10,15,30,60,120\" (minutes). Any other separator (;, space) is "
                "NOT recognised and would return a single token.");
      return;
     }
   if(nParts > HP_MAX_HORIZONS)
     {
      HP_Reject("HP_Horizons", IntegerToString(nParts) + " horizons",
                "<= " + IntegerToString(HP_MAX_HORIZONS),
                "Hard bound of the script — beyond it, reading the table stops making sense.");
      return;
     }
   int hor[HP_MAX_HORIZONS];
   int nHor = 0;
   for(int i = 0; i < nParts; i++)
     {
      string t = parts[i];
      StringTrimLeft(t);
      StringTrimRight(t);
      // STRICT VALIDATION, character by character: StringToInteger follows the
      // atol semantics — "5 min", "1.5", "1;2;5" returned plausible values IN
      // SILENCE, and an empty token was skipped without a word. A MEASUREMENT
      // script does not guess what the user meant.
      const int len = StringLen(t);
      if(len < 1 || len > 9)
        {
         HP_Reject("HP_Horizons", "token no." + IntegerToString(i + 1) + " = \"" + t + "\"",
                   "1 to 9 digits",
                   "Empty or overlong token — check the commas in the list.");
         return;
        }
      for(int c = 0; c < len; c++)
        {
         const ushort ch = StringGetCharacter(t, c);
         if(ch < '0' || ch > '9')
           {
            HP_Reject("HP_Horizons", "token no." + IntegerToString(i + 1) + " = \"" + t + "\"",
                      "DIGITS only (whole minutes)",
                      "No decimal, no unit, no other separator: \"5 min\", \"1.5\" and \"1;2\" "
                      "would be misread.");
            return;
           }
        }
      const int h = (int)StringToInteger(t);
      if(h <= 0)
        {
         HP_Reject("HP_Horizons", "\"" + t + "\"", "integer > 0 (minutes)",
                   "A zero horizon means nothing.");
         return;
        }
      for(int j = 0; j < nHor; j++)
         if(hor[j] == h)
           {
            HP_Reject("HP_Horizons", "horizon " + IntegerToString(h) + " DUPLICATED",
                      "distinct horizons",
                      "A repeated row measures nothing more and distorts the reading of the table.");
            return;
           }
      hor[nHor++] = h;
     }
   if(nHor == 0)
     {
      HP_Reject("HP_Horizons", "\"" + HP_Horizons + "\"", "at least one valid horizon",
                "The list contains no usable integer.");
      return;
     }
   //--- v1.02: the date bounds. 0 (or 1970) = no bound.
   if(HP_DateFrom > 0 && HP_DateTo > 0 && HP_DateFrom >= HP_DateTo)
     {
      HP_Reject("HP_DateFrom/HP_DateTo",
                TimeToString(HP_DateFrom, TIME_DATE|TIME_MINUTES) + " / " +
                TimeToString(HP_DateTo, TIME_DATE|TIME_MINUTES),
                "HP_DateFrom STRICTLY earlier than HP_DateTo",
                "An empty or reversed period would measure nothing. Leave both at 1970 to take "
                "ALL the history read.");
      return;
     }

   //================================================================
   //  1. THE INSTRUMENT. The SYMBOL comes from the chart; the TIMEFRAME
   //     is ignored: horizons are in MINUTES, so the measurement is on M1.
   //================================================================
   const string sym = _Symbol;
   if(_Period != PERIOD_M1)
      PrintFormat("SB [HORIZON] ⚠️ chart on %s: horizons are in MINUTES, so the measurement is made "
                  "on M1 — only the SYMBOL (%s) is taken from the chart.",
                  EnumToString((ENUM_TIMEFRAMES)_Period), sym);

   const double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   const double tickSize  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   const double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0)
     {
      PrintFormat("SB [HORIZON] ⛔ UNUSABLE symbol specification (%s): tick_value %.5f, tick_size %.5f, "
                  "point %.5f — points cannot be converted into money. Measurement abandoned.",
                  sym, tickValue, tickSize, point);
      return;
     }
   const double valuePerPoint = tickValue * (point / tickSize) * HP_Lots;

   //================================================================
   //  2. THE M1 HISTORY.
   //================================================================
   const int available = Bars(sym, PERIOD_M1);
   int want = (int)MathMin((double)HP_MaxBars, (double)available);
   int hMax = 0;
   for(int i = 0; i < nHor; i++)
      if(hor[i] > hMax)
         hMax = hor[i];
   if(want < hMax + 100)
     {
      PrintFormat("SB [HORIZON] ⛔ INSUFFICIENT HISTORY: %d M1 bar(s) available on %s (HP_MaxBars "
                  "bound %d), at least %d are needed for the longest horizon (%d min). "
                  "Load the M1 history (%s chart on M1, scroll into the past) then run again. "
                  "The download is ASYNCHRONOUS: a second run may be enough. NEVER a "
                  "silently truncated measurement.",
                  available, sym, HP_MaxBars, hMax + 100, hMax, sym);
      return;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, false);        // index 0 = the OLDEST (explicit, never assumed)
   // ⚠️ READ FROM POSITION 1: bar 0 is STILL FORMING — its close moves, and so
   // does its spread. Including it made the last window, the date range AND the
   // spread distribution unstable from one run to the next.
   const int got = CopyRates(sym, PERIOD_M1, 1, want, rates);
   if(got <= 0)
     {
      PrintFormat("SB [HORIZON] ⛔ CopyRates returned %d for %d M1 bar(s) requested on %s "
                  "(error %d) — measurement abandoned. The M1 download is asynchronous: run again.",
                  got, want, sym, GetLastError());
      return;
     }
   if(got < hMax + 100)
     {
      PrintFormat("SB [HORIZON] ⛔ CopyRates served only %d bar(s) out of %d requested — fewer than the "
                  "%d required for the longest horizon (%d min). The M1 download is ASYNCHRONOUS: "
                  "run again once it has loaded. Measurement abandoned (never silently truncated).",
                  got, want, hMax + 100, hMax);
      return;
     }
   if(got < want)
      PrintFormat("SB [HORIZON] ⚠️ %d M1 bar(s) obtained out of %d requested: the terminal caps the "
                  "history it serves. The measurement covers WHAT WAS READ.", got, want);

   PrintFormat("═══ HORIZON PROBE v1.02 — %s, %d M1 bar(s) from %s to %s (forming bar EXCLUDED) ═══",
               sym, got,
               TimeToString(rates[0].time, TIME_DATE|TIME_MINUTES),
               TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES));
   string horList = "";
   int hMin = hMax;
   for(int i = 0; i < nHor; i++)
     {
      horList += (i > 0 ? ", " : "") + IntegerToString(hor[i]);
      if(hor[i] < hMin)
         hMin = hor[i];
     }
   PrintFormat("Horizons KEPT (%d, in minutes): %s — the list is republished so it can be checked by eye.",
               nHor, horList);

   //================================================================
   //  2 bis. THE MEASURED PERIOD (v1.02) — bounds on the OPENING of the
   //     windows. With the defaults (1970/1970): iFrom = 0, iTo = got-1,
   //     so ALL the history read, and the table is the v1.01 one bit for
   //     bit (the loop bounds coincide).
   //================================================================
   int iFrom = 0, iTo = got - 1;
   if(HP_DateFrom > 0)
      while(iFrom <= iTo && rates[iFrom].time < HP_DateFrom)
         iFrom++;
   if(HP_DateTo > 0)
      while(iTo >= iFrom && rates[iTo].time > HP_DateTo)
         iTo--;
   if(iFrom > iTo)
     {
      PrintFormat("SB [HORIZON] ⛔ NO M1 bar inside the requested period [%s ; %s]: the history read "
                  "runs from %s to %s. No window can open in that interval — never an empty "
                  "table in silence. Measurement abandoned.",
                  (HP_DateFrom > 0 ? TimeToString(HP_DateFrom, TIME_DATE|TIME_MINUTES) : "start"),
                  (HP_DateTo   > 0 ? TimeToString(HP_DateTo,   TIME_DATE|TIME_MINUTES) : "end"),
                  TimeToString(rates[0].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES));
      return;
     }
   //--- At least ONE window must be able to open, for the SHORTEST horizon:
   //    otherwise the table would be empty row after row. (iFrom <= iTo is
   //    ALREADY guaranteed by the refusal above: the only remaining
   //    impossibility is the lack of bars AFTER the opening.)
   if(iFrom + hMin >= got)
     {
      PrintFormat("SB [HORIZON] ⛔ NO usable window inside the requested period: %d bar(s) "
                  "kept [%s ; %s], and at least %d bar(s) are needed after the opening for the "
                  "shortest horizon (%d min) — the history ends on %s. Measurement abandoned.",
                  iTo - iFrom + 1,
                  TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[iTo].time, TIME_DATE|TIME_MINUTES),
                  hMin, hMin, TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES));
      return;
     }
   const bool ranged = (HP_DateFrom > 0 || HP_DateTo > 0);
   if(ranged)
      PrintFormat("⚠️ TIME REFERENCE: the date bounds are compared to the SERVER clock "
                  "(%s, current offset GMT%+d) — the SAME date entered on another broker does "
                  "NOT designate the same instant. This is the reference of rates[].time, and of the "
                  "whole script.",
                  AccountInfoString(ACCOUNT_SERVER),
                  (int)((TimeTradeServer() - TimeGMT()) / 3600));
   if(!ranged)
      PrintFormat("MEASURED PERIOD: ALL the history read (date bounds at their default) — from %s to %s, "
                  "%d bar(s).",
                  TimeToString(rates[0].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES), got);
   else
     {
      PrintFormat("MEASURED PERIOD — REQUESTED: [%s ; %s] | ACTUALLY OBTAINED: [%s ; %s], %d opening "
                  "bar(s) kept out of %d read. ⚠️ These bounds apply to the OPENING of the windows: "
                  "a window is allowed to END after the end bound (otherwise H=%d would lose "
                  "%d min more than H=%d and the columns would no longer be comparable).",
                  (HP_DateFrom > 0 ? TimeToString(HP_DateFrom, TIME_DATE|TIME_MINUTES) : "start of history"),
                  (HP_DateTo   > 0 ? TimeToString(HP_DateTo,   TIME_DATE|TIME_MINUTES) : "end of history"),
                  TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[iTo].time,   TIME_DATE|TIME_MINUTES),
                  iTo - iFrom + 1, got, hMax, hMax - hMin, hMin);
      //--- ⚠️ THE REQUEST IS NOT COVERED: it SHOUTS, it does not truncate in
      //    silence (the very reason for this version: a first run measured
      //    seven weeks while believing it measured two years).
      if(HP_DateFrom > 0 && HP_DateFrom < rates[0].time)
        {
         // ⚠️ CALENDAR MINUTES, not bars: the market does not quote
         // continuously, so this is an UPPER BOUND on the number of missing
         // bars. The estimate from the ACTUALLY observed density is published
         // next to it.
         const long missMin = (long)(rates[0].time - HP_DateFrom) / 60;
         const long span    = (long)(rates[got - 1].time - rates[0].time);
         const double dens  = (span > 0 ? (double)got / (span / 60.0) : 0.0);   // bars per calendar minute
         PrintFormat("⛔ START NOT COVERED: the requested period begins on %s, but the history READ "
                     "only goes back to %s — %d CALENDAR minute(s) of difference (UPPER BOUND on the "
                     "number of missing M1 bars: weekends carry none; at the observed density "
                     "of %.2f bar/min, the order of magnitude is ~%d bars). The measurement covers a "
                     "SHORTER period than the one requested — raise HP_MaxBars and/or load the "
                     "M1 history (chart on M1, scroll into the past).",
                     TimeToString(HP_DateFrom, TIME_DATE|TIME_MINUTES),
                     TimeToString(rates[0].time, TIME_DATE|TIME_MINUTES),
                     (int)missMin, dens, (int)(missMin * dens));
        }
      if(HP_DateTo > 0 && HP_DateTo > rates[got - 1].time)
         PrintFormat("⛔ END NOT COVERED: the requested period runs until %s, but the history READ "
                     "stops on %s. The measurement covers a SHORTER period than the one requested.",
                     TimeToString(HP_DateTo, TIME_DATE|TIME_MINUTES),
                     TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES));
     }
   PrintFormat("Conversion: %.2f lot, tick_value %.5f / tick_size %.5f / point %.5f => %.5f per point. "
               "⚠️ Tick value read NOW (account currency %s) and applied to the whole history: "
               "the money column is a CURRENT valuation of past amplitudes. The RATIOS are in POINTS "
               "and do NOT depend on it.",
               HP_Lots, tickValue, tickSize, point, valuePerPoint,
               AccountInfoString(ACCOUNT_CURRENCY));

   //================================================================
   //  3. THE COST — the OBSERVED SPREAD. Zero-spread bars counted and
   //     excluded; regime detected (modal value, halves).
   //================================================================
   //--- v1.02: the distribution is computed OVER THE KEPT PERIOD (iFrom..iTo)
   //    and not over the whole history — the spread of one year is not the
   //    spread of the next, which is the very point of this version. With the
   //    defaults, iFrom = 0 and iTo = got-1: the bounds coincide with v1.01,
   //    bit for bit.
   const int nRange = iTo - iFrom + 1;
   double sp[];
   if(!HP_Resize(sp, nRange, "spread distribution"))
      return;
   int nZero = 0, nSp = 0;
   for(int i = iFrom; i <= iTo; i++)
     {
      if(rates[i].spread <= 0)
        {
         nZero++;
         continue;                        // excluded from the median, counted and SAID
        }
      sp[nSp++] = (double)rates[i].spread;
     }
   if(nSp == 0)
     {
      PrintFormat("SB [HORIZON] ⛔ NO bar carries a spread over the measured period (%d bars at "
                  "spread 0): no observable cost — every move would \"exceed\" a cost of zero and "
                  "the table would mean NOTHING (custom symbol, imported ticks, badly configured "
                  "tester). Measurement abandoned.", nRange);
      return;
     }
   if(!HP_Resize(sp, nSp, "spread distribution (compacted)"))
      return;
   ArraySort(sp);
   const double spMin = sp[0];
   const double spMed = HP_Quantile(sp, 0.50);
   const double spP90 = HP_Quantile(sp, 0.90);
   const double spMax = sp[nSp - 1];
   //--- THE ROUND-TRIP COST: crossing the spread once IS the full cost of a
   //    round trip at the same price. ROUNDED to whole points (prices sit on
   //    the point grid: a cost interpolated at 24.5 would compare integers to a
   //    half-unit, and the published value would not be the one used). The
   //    rounding is SAID.
   const double costPts = MathRound(spMed);

   //--- ⛔ ZERO-COST TEST: INDEPENDENT and FIRST (it used to sit in an `else if`
   //    behind the constant-spread test, hence UNREACHABLE in the most frequent
   //    case: a history entirely at spread 0 printed "constant spread" and still
   //    published a zero-cost table, CEILING ~99 % everywhere).
   if(costPts <= 0.0)
     {
      PrintFormat("SB [HORIZON] ⛔ MEDIAN COST IS ZERO (median %.2f pt over %d bar(s) with a spread): "
                  "there is no toll to cross, the table would mean NOTHING. Measurement abandoned.",
                  spMed, nSp);
      return;
     }

   PrintFormat("MEASURED ROUND-TRIP COST: MEDIAN observed spread %.2f pts (rounded to %.0f pts for the "
               "measurement) = %.2f for %.2f lot. ⚠️ COMMISSION and SLIPPAGE NOT included (the first "
               "never measured on this account, the second not measurable from bars): this cost is a "
               "FLOOR, and any CEILING an OPTIMISTIC upper bound.",
               spMed, costPts, costPts * valuePerPoint, HP_Lots);
   PrintFormat("Spread distribution: min %.2f / median %.2f / p90 %.2f / max %.2f pts "
               "(in account currency for %.2f lot: %.2f / %.2f / %.2f / %.2f).",
               spMin, spMed, spP90, spMax, HP_Lots,
               spMin * valuePerPoint, spMed * valuePerPoint,
               spP90 * valuePerPoint, spMax * valuePerPoint);
   if(nZero > 0)
      PrintFormat("⚠️ %d bar(s) out of %d (%.1f%%) carry a ZERO spread: EXCLUDED from the median "
                  "(computed over %d bar(s) that do carry one). A MIXED history signals a partially "
                  "imported source — the median then describes only the priced part.",
                  nZero, nRange, 100.0 * nZero / nRange, nSp);
   //--- Regime: MODAL value and chronological halves (min==max alone did not
   //    see a regime change happening inside the history).
   int modeCount = 1, bestCount = 1;
   double modeVal = sp[0];
   for(int i = 1; i < nSp; i++)
     {
      if(sp[i] == sp[i - 1]) modeCount++;
      else                   modeCount = 1;
      if(modeCount > bestCount) { bestCount = modeCount; modeVal = sp[i]; }
     }
   const double modeShare = (double)bestCount / nSp;
   double h1[], h2[];
   //--- CHRONOLOGICAL halves of the kept period (v1.02). With the defaults,
   //    mid = 0 + got/2: the v1.01 split, identically.
   const int mid = iFrom + nRange / 2;
   int n1 = 0, n2 = 0;
   if(!HP_Resize(h1, nRange / 2 + 1, "spread, 1st half") ||
      !HP_Resize(h2, nRange - nRange / 2 + 1, "spread, 2nd half"))
      return;
   for(int i = iFrom; i <= iTo; i++)
     {
      if(rates[i].spread <= 0)
         continue;
      if(i < mid) h1[n1++] = (double)rates[i].spread;
      else        h2[n2++] = (double)rates[i].spread;
     }
   double med1 = 0.0, med2 = 0.0;
   if(n1 > 0) { HP_Resize(h1, n1, "spread, 1st half"); ArraySort(h1); med1 = HP_Quantile(h1, 0.50); }
   if(n2 > 0) { HP_Resize(h2, n2, "spread, 2nd half"); ArraySort(h2); med2 = HP_Quantile(h2, 0.50); }
   // An explicit "n/a" when a half carries NO priced bar at all: 0.00 would read
   // as a spread MEASURED at zero — the most optimistic value possible — instead
   // of an undefined one.
   const string med1Txt = (n1 > 0 ? StringFormat("%.2f", med1) : "n/a (0 bar with a spread)");
   const string med2Txt = (n2 > 0 ? StringFormat("%.2f", med2) : "n/a (0 bar with a spread)");
   PrintFormat("Spread regime: MODAL value %.0f pts on %.1f%% of the bars; median of 1st half "
               "%s / 2nd half %s pts.", modeVal, 100.0 * modeShare, med1Txt, med2Txt);
   bool costSuspect = false;
   // MIXED SOURCE: one half entirely unpriced. Without this case, the
   // "regime change" alarm (which requires med1 > 0 AND med2 > 0) was DISARMED
   // by the mixed source itself — precisely what it was meant to catch.
   if((n1 == 0) != (n2 == 0))
     {
      costSuspect = true;
      Print("⛔ MIXED SOURCE: one half of the period carries NO spread at all (import at "
            "spread 0 on one side, live on the other) — the median cost describes ONLY the other half.");
     }
   if(spMin == spMax)
     {
      costSuspect = true;
      PrintFormat("⛔ CONSTANT SPREAD (%.0f pts over the %d priced bars): source in FIXED SPREAD. "
                  "The cost of this measurement is an ARBITRARY CONSTANT, not an observed cost.", spMin, nSp);
     }
   else if(modeShare > 0.90)
     {
      costSuspect = true;
      PrintFormat("⛔ NEARLY FIXED SPREAD: %.1f%% of the bars carry the same value (%.0f pts). The cost is "
                  "close to a constant — same reservation as a fixed spread.", 100.0 * modeShare, modeVal);
     }
   if(n1 > 0 && n2 > 0 && med1 > 0.0 && med2 > 0.0 &&
      (med2 / med1 > 2.0 || med1 / med2 > 2.0))
     {
      costSuspect = true;
      PrintFormat("⛔ REGIME CHANGE: the median spread goes from %.2f to %.2f pts between the two "
                  "halves of the history (factor %.1f). A GLOBAL MEDIAN cost then describes neither "
                  "period.", med1, med2, MathMax(med2 / med1, med1 / med2));
     }

   //================================================================
   //  4. PRE-COMPUTING THE PAUSES — index of the last bar preceded by
   //     a gap >= 30 min, in O(n): used to classify an exclusion on
   //     THE LARGEST GAP of the window and not on the cumulated
   //     excess (at long horizons, 30 scattered missing minutes were
   //     labelled "pause").
   //================================================================
   int lastPause[];
   if(ArrayResize(lastPause, got) != got)
     {
      HP_Reject("HP_MaxBars", IntegerToString(got), "a size that fits in memory",
                "Allocation refused for the pause index — lower HP_MaxBars.");
      return;
     }
   lastPause[0] = -1;
   for(int i = 1; i < got; i++)
      lastPause[i] = (((long)(rates[i].time - rates[i - 1].time) >= HP_PAUSE_SECONDS)
                        ? i : lastPause[i - 1]);

   //================================================================
   //  5. THE TABLE.
   //================================================================
   // Title and footer are CONDITIONAL: in bounded mode, "every window of the
   // history read" would be FALSE.
   if(ranged)
      PrintFormat("─── ORACLE CEILING, PER HORIZON (windows OPENING inside [%s ; %s]) ───",
                  TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[iTo].time,   TIME_DATE|TIME_MINUTES));
   else
      Print("─── ORACLE CEILING, PER HORIZON (all rolling windows) ───");
   Print("★ THE PROFITABILITY JUDGE IS THE EXPECTANCY (MEAN ampl. - cost): an oracle with a PERFECT "
         "direction earns (|d| - cost) on every window, so it is profitable IFF mean(|d|) > cost. "
         "The CEILING (share of windows where |d| > cost) measures something else: with fat tails "
         "(median << mean) an oracle can be very profitable with FEWER than half the windows "
         "above the toll. The MARGIN (CEILING - THRESHOLD) is published for the record but "
         "subtracts TWO RATES OF DIFFERENT NATURES: an indicator, never a verdict.");
   Print("ROLLING windows at a 1 min step: they OVERLAP (H-1 minutes in common) and are "
         "NOT independent draws — the non-overlapping equivalent (~used/H) is published and it is THAT "
         "one which carries the 10 000 rule. STRICT counting: a move EQUAL to the cost does not pay the "
         "toll and is not counted. \"gap >= 30 min\" / \"gap < 30 min\" = what is MEASURED (a "
         "duration), not the cause (the script does not tell a weekend from a data hole).");

   double amp[];
   if(!HP_Resize(amp, got, "amplitudes"))
      return;

   for(int k = 0; k < nHor; k++)
     {
      const int  H    = hor[k];
      const long need = (long)H * 60;

      int    used = 0, exclPause = 0, exclMissing = 0;
      int    over = 0, overWin = 0, usedWin = 0, atCost = 0;
      double sumAmp = 0.0;
      // v1.02: the last opening ACTUALLY measurable for THIS horizon. It
      // depends on H as soon as the period reaches the end of the data read —
      // the inequality that the "free end" bound avoids on the To side comes
      // back from the data side, and it is SAID on the line.
      const int iLast = (int)MathMin((double)iTo, (double)(got - 1 - H));

      // v1.02: the OPENING i is bounded to the period [iFrom ; iTo]; the END
      // (i+H) is bounded only by the data — a window is allowed to end after
      // HP_DateTo (otherwise long horizons would be truncated more and the
      // columns would stop being comparable). With the defaults, iFrom = 0 and
      // iTo = got-1: the binding condition becomes "i + H < got" again, exactly
      // the v1.01 loop.
      for(int i = iFrom; i <= iTo && i + H < got; i++)
        {
         // A window is kept IFF it lasts EXACTLY H minutes.
         const long elapsed = (long)(rates[i + H].time - rates[i].time);
         if(elapsed != need)
           {
            // Classified on THE LARGEST GAP INSIDE the window.
            if(lastPause[i + H] > i) exclPause++;
            else                     exclMissing++;
            continue;
           }
         // EXPLICIT quantisation: prices are multiples of the point, so the
         // rounding is exact — it removes the binary-rounding lottery on
         // windows sitting exactly at the cost.
         const double d = MathRound(MathAbs(rates[i + H].close - rates[i].close) / point);
         amp[used] = d;
         sumAmp   += d;
         if(d > costPts)                        // MEDIAN cost (strict)
            over++;
         else if(d == costPts)
            atCost++;
         // WINDOW COST: only on PRICED openings — a bar at spread 0 (imported
         // history) would give a toll of ZERO and let ~all of its windows
         // through, inflating the very column that is meant to quantify the
         // bias of a constant cost (the contamination would have read as a
         // spread/move correlation).
         if(rates[i].spread > 0)
           {
            usedWin++;
            if(d > (double)rates[i].spread)
               overWin++;
           }
         used++;
        }

      const int seen = used + exclPause + exclMissing;
      if(seen == 0)
        {
         // STRUCTURAL cause, distinguished from "everything was discarded": no
         // window could even OPEN — the period starts too close to the end of
         // the data read for this horizon.
         PrintFormat("H=%3d min | ⛔ NO window can OPEN: the period starts on %s and "
                     "the history read ends on %s — %d min are needed after the opening. "
                     "STRUCTURAL cause: no window was DISCARDED, there were none.",
                     H, TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                     TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES), H);
         continue;
        }
      if(used == 0)
        {
         PrintFormat("H=%3d min | ⛔ NO usable window out of %d (gap >= 30 min: %d, gap < 30 "
                     "min: %d) — this horizon measures NOTHING.", H, seen, exclPause, exclMissing);
         continue;
        }

      double ampUsed[];
      if(!HP_Resize(ampUsed, used, "kept amplitudes"))
         return;
      ArrayCopy(ampUsed, amp, 0, 0, used);
      ArraySort(ampUsed);
      const double ampMed  = HP_Quantile(ampUsed, 0.50);
      const double ampMean = sumAmp / used;

      const double ceiling    = (double)over / used;      // CEILING, median cost
      // CEILING at the window cost: related to the PRICED openings only, and
      // "n/a" if there are none (never a number in place of an undefined value).
      const string ceilWinTxt = (usedWin > 0
                                   ? StringFormat("%5.1f%%", 100.0 * overWin / usedWin)
                                   : "  n/a");
      const double expect     = ampMean - costPts;        // ★ ORACLE EXPECTANCY (points)
      const int    indep      = used / H;                 // NON-overlapping equivalent
      const double retention  = (double)used / seen;

      //--- Ratio and threshold: explicit "n/a" if the amplitude is zero — a
      //    measuring instrument NEVER substitutes a number (0.0, which is here
      //    the MOST optimistic value) for an undefined one.
      const string ratioTxt = (ampMed > 0.0
                                 ? StringFormat("%5.1f%%", 100.0 * costPts / ampMed)
                                 : "  n/a (MEDIAN ampl. is ZERO)");
      string seuilTxt, margeTxt;
      if(ampMean > 0.0)
        {
         const double thresh = 0.5 + costPts / (2.0 * ampMean);
         seuilTxt = (thresh > 1.0
                       ? StringFormat("%5.1f%% ⛔ UNREACHABLE (> 100 %%: even a PERFECT direction "
                                      "does not pay the toll)", 100.0 * thresh)
                       : StringFormat("%5.1f%%", 100.0 * thresh));
         margeTxt = StringFormat("%+6.1f pts of %%", 100.0 * (ceiling - thresh));
        }
      else
        {
         seuilTxt = "n/a"; margeTxt = "n/a (no amplitude on this horizon)";
        }

      PrintFormat("H=%3d min | windows %7d (~%6d non-overlapping) | retention %5.1f%% "
                  "[gap >= 30 min %6d / gap < 30 min %6d] | CEILING %5.1f%% (median cost) / %s "
                  "(window cost, over %d priced opening(s)) | median ampl. %7.0f pts "
                  "(%8.2f), mean %7.0f pts | cost/median ampl. %s | ★ ORACLE EXPECTANCY %+8.0f pts "
                  "(%+8.2f) %s | THRESHOLD %s | MARGIN %s%s%s%s%s",
                  H, used, indep, 100.0 * retention, exclPause, exclMissing,
                  100.0 * ceiling, ceilWinTxt, usedWin,
                  ampMed, ampMed * valuePerPoint, ampMean,
                  ratioTxt,
                  expect, expect * valuePerPoint,
                  (expect > 0.0 ? "(> 0: a PERFECT direction pays the toll)"
                                : "⛔ (<= 0: even a PERFECT direction does not pay the toll)"),
                  seuilTxt, margeTxt,
                  (atCost > 0 ? StringFormat(" | %d window(s) EXACTLY at the cost (not counted, strict)",
                                             atCost) : ""),
                  (indep < HP_MIN_WINDOWS
                     ? StringFormat(" | ⚠️ ~%d INDEPENDENT windows (< %d): NOT CONCLUSIVE",
                                    indep, HP_MIN_WINDOWS) : ""),
                  (retention < HP_MIN_RETENTION
                     ? StringFormat(" | ⚠️ retention %.1f%%: the windows kept are those WITHOUT a "
                                    "missing minute, hence the most ACTIVE stretches — amplitude and "
                                    "ceiling biased UPWARDS", 100.0 * retention) : ""),
                  // v1.02: the end of the period is truncated by the DATA, and H
                  // times harder for horizon H — that column then does not cover
                  // the same time window as the others. Said on the line, never
                  // assumed.
                  // ⚠️ ONLY in PERIOD mode: with the default, iTo = got-1 and
                  // "the last H bars open no window" is the normal situation of
                  // any history — no bound was PUBLISHED that could mislead, and
                  // warning on every line would break the identity of the table
                  // with v1.01.
                  (ranged && iLast < iTo
                     ? StringFormat(" | ⚠️ last MEASURED opening %s (the history read ends on %s) "
                                    ": %d end-of-period opening(s) not measurable for H=%d — "
                                    "cross-column comparison degraded on the tail",
                                    TimeToString(rates[iLast].time, TIME_DATE|TIME_MINUTES),
                                    TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES),
                                    iTo - iLast, H) : ""));
     }

   if(costSuspect)
      Print("⛔ REMINDER BELOW THE TABLE: the cost of this run is suspect (fixed spread, nearly fixed, or "
            "regime change — see above). EVERY line above depends on it: they do not "
            "measure an observed cost. Repeating this reminder here is deliberate — a reader who only "
            "reads the table must not be able to miss it.");
   if(ranged)
      PrintFormat("═══ END — this script MEASURES, it optimises nothing and trades nothing. No "
                  "distribution assumption: every window OPENING inside [%s ; %s] was walked "
                  "(%d candidate opening(s) out of %d bar(s) read). ═══",
                  TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[iTo].time,   TIME_DATE|TIME_MINUTES), nRange, got);
   else
      Print("═══ END — this script MEASURES, it optimises nothing and trades nothing. No "
            "distribution assumption: every rolling window of the history read was walked. ═══");
  }
//+------------------------------------------------------------------+
