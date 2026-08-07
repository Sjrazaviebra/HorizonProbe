//+------------------------------------------------------------------+
//| HorizonProbe.mq5 — LE PLAFOND DE L'ORACLE, MESURÉ PAR HORIZON |
//|                                                                  |
//| ⚠️ C'EST UN SCRIPT, PAS UN EXPERT ADVISOR : il ne trade RIEN, il |
//| n'ouvre RIEN, il ne lit aucun paramètre d'EA. Même esprit que |
//| le passeport d'instrument — un outil de DIAGNOSTIC AUTONOME et   |
//| DÉTACHABLE : aucun #include, aucune dépendance externe.  |
//| Il se copie tel quel dans n'importe quel terminal.               |
//|                                                                  |
//| POURQUOI IL EXISTE : le plafond de l'oracle par horizon est souvent   |
//| ESTIMÉ — mise à l'échelle en racine du temps et approximation    |
//| gaussienne. L'or a des queues épaisses, et une gaussienne |
//| sous-estime précisément ce qui compte : les grands mouvements.   |
//| sous-estime précisément ce qui compte : les grands mouvements.   |
//| Ce script REMPLACE le calcul par une MESURE : toutes les         |
//| fenêtres glissantes, le coût réel observé, aucune hypothèse.     |
//|                                                                  |
//| ── CE QU'IL PUBLIE, HORIZON PAR HORIZON (H en MINUTES) ─────────  |
//| • PLAFOND (coût médian) = part des fenêtres où le mouvement      |
//|   |close(t+H) − close(t)| DÉPASSE le coût A/R médian.            |
//| • PLAFOND (coût de la fenêtre) = le même compte, mais chaque     |
//|   fenêtre jugée au spread RÉELLEMENT observé à son entrée.       |
//|   L'ÉCART ENTRE LES DEUX CHIFFRE le biais du coût constant : le  |
//|   spread de l'or explose quand le mouvement est grand — juger    |
//|   une minute de news au péage d'une heure calme SURESTIME le     |
//|   plafond (revue : la mesure par fenêtre était disponible dans   |
//|   le même tableau, on ne la suppose plus).                       |
//| • ★ ESPÉRANCE DE L'ORACLE = amplitude MOYENNE − coût. C'EST LE   |
//|   JUGE DE RENTABILITÉ d'une direction parfaite : un oracle qui   |
//|   trade chaque fenêtre gagne (|d| − coût) à chaque fois, donc il |
//|   est rentable SSI moyenne(|d|) > coût. ⚠️ CE N'EST PAS le       |
//|   PLAFOND : le plafond compte les fenêtres individuellement      |
//|   gagnantes, et avec des queues épaisses (médiane ≪ moyenne) un  |
//|   oracle peut être largement rentable avec moins de la moitié    |
//|   des fenêtres au-dessus du péage (revue v1.01 : le verdict tiré |
//|   du seul plafond était systématiquement PESSIMISTE — sur l'or,  |
//|   c'est-à-dire précisément là où ce script sert).                |
//| • SEUIL D'ÉQUILIBRE = 0,5 + coût / (2 × amplitude moyenne) : le  |
//|   taux de bonne direction requis pour rentrer dans ses frais.    |
//|   Il se compare à 100 % (le taux d'un oracle) : au-delà de       |
//|   100 %, INATTEIGNABLE même parfait.                             |
//| • MARGE = PLAFOND − SEUIL, publiée pour mémoire et      |
//|   conservée telle quelle — ⚠️ MAIS c'est la DIFFÉRENCE DE DEUX   |
//|   TAUX DE NATURES DIFFÉRENTES (une part de fenêtres moins un     |
//|   taux de réussite requis) : elle se lit comme un indicateur,    |
//|   JAMAIS comme le verdict de rentabilité. Le verdict, c'est      |
//|   l'ESPÉRANCE ci-dessus.                                         |
//| • Fenêtres retenues, équivalent NON CHEVAUCHANT (≈ used/H — les  |
//|   fenêtres glissantes ne sont PAS des tirages indépendants), et  |
//|   les fenêtres écartées.                                         |
//|                                                                  |
//| ── LE COÛT ────────────────────────────────────────────────────  |
//| Le SPREAD OBSERVÉ DANS L'HISTORIQUE (médiane de MqlRates.spread  |
//| sur les barres lues), JAMAIS une constante ni le spread courant. |
//| Distribution publiée (min/médiane/p90/max), part de la valeur    |
//| MODALE, et médianes des deux MOITIÉS chronologiques : un spread  |
//| fixe, ou un CHANGEMENT DE RÉGIME en cours d'historique, se       |
//| voient — leçon v1.33, une porte spread lancée en spread fixe     |
//| n'aurait rien testé et personne ne l'aurait vu. Les barres à     |
//| spread 0 (historique importé, symbole custom) sont COMPTÉES et   |
//| ÉCARTÉES du calcul de la médiane, en le disant.                  |
//| ⚠️ MqlRates.spread est le spread ENREGISTRÉ par le terminal pour |
//| la barre (son instant exact d'échantillonnage n'est pas          |
//| documenté) : source dite ici, jamais supposée.          |
//| ⚠️ COMMISSION et SLIPPAGE NON inclus — la première n'a jamais    |
//| été mesurée sur ce compte, le second n'est pas mesurable depuis  |
//| un historique de barres. Le coût publié est donc un PLANCHER, et |
//| tout PLAFOND une borne haute OPTIMISTE.                          |
//|                                                                  |
//| ── LES FENÊTRES ÉCARTÉES ──────────────────────────────────────  |
//| Une fenêtre n'est retenue QUE si (time[t+H] − time[t]) == H × 60 |
//| exactement : cela écarte d'un coup les pauses ET les minutes     |
//| manquantes (une fenêtre à barres absentes ne dure pas H minutes, |
//| elle mesurerait autre chose). Les deux causes sont classées sur  |
//| LE PLUS GRAND ÉCART entre deux barres consécutives DANS la       |
//| fenêtre (et non sur l'excès cumulé — revue). ⚠️ Le script mesure |
//| une DURÉE, il n'observe pas la CAUSE : un week-end et un trou de |
//| données de 30 min sont indiscernables, les colonnes sont donc    |
//| nommées « écart >= 30 min » / « écart < 30 min ».                |
//| ⚠️ BIAIS ASSUMÉ ET PUBLIÉ : écarter les fenêtres à minute creuse |
//| retire préférentiellement les plages CALMES => l'amplitude et le |
//| plafond mesurés sont ceux du sous-ensemble le plus actif. Le     |
//| TAUX DE RÉTENTION est publié par horizon pour le chiffrer.       |
//|                                                                  |
//| ── LES BORNES DE DATE (v1.02) ─────────────────────────────────  |
//| MOTIF MESURÉ le 05/08/2026 : le premier run n'avait lu que       |
//| 50 005 barres M1 (16/06 → 05/08/2026) — sept semaines, pas les   |
//| fenêtres usuelles. Et même avec l'historique complet, une mesure  |
//| unique sur 2024-2026 MOYENNERAIT DEUX RÉGIMES : entre le T1 2024 |
//| et l'été 2026, l'amplitude médiane par minute est passée         |
//| d'environ 24 à 74 points pendant que le prix doublait. Ce script   |
//| sépare ses fenêtres depuis juin ; la sonde fait pareil.          |
//|                                                                  |
//| SÉMANTIQUE : une fenêtre glissante n'est retenue que si SON      |
//| OUVERTURE t tombe dans [HP_DateFrom, HP_DateTo].                 |
//| ⚠️ LA FENÊTRE A LE DROIT DE SE TERMINER APRÈS HP_DateTo — et     |
//| c'est VOULU : borner aussi la fin tronquerait les horizons longs |
//| de façon INÉGALE (H=120 perdrait 2 h de plus que H=1) et les     |
//| colonnes du tableau ne seraient plus comparables entre elles.    |
//| Conséquence assumée : les dernières fenêtres d'une période       |
//| lisent des barres postérieures à To. C'est dit ici ET dans la    |
//| ligne de sortie.                                                 |
//| LE COÛT EST RECALCULÉ SUR LA PÉRIODE (distribution, régime,      |
//| barres à spread nul) — le spread de 2024 n'est pas celui de      |
//| 2026, c'est tout l'objet de la version. Le compte de fenêtres et |
//| le taux de rétention sont eux aussi relatifs à la période.       |
//| Aux défauts (les deux dates à 1970), TOUT l'historique lu est    |
//| retenu : le tableau est celui de la v1.01, bit à bit.            |
//|                                                                  |
//| HORIZONS EN MINUTES => LA MESURE SE FAIT SUR M1, quelle que soit |
//| la période du graphique (seul le SYMBOLE est repris).            |
//| ⚠️ CE SCRIPT MESURE, IL N'OPTIMISE RIEN.                         |
//+------------------------------------------------------------------+
#property copyright "Javad Razavi — The Solution Maker"
#property version   "1.02"
#property script_show_inputs

input double HP_Lots     = 0.01;                    // Taille de reference pour convertir les points en $. Convention d'affichage. N'influence AUCUN ratio — seulement l'affichage en $.
input int    HP_MaxBars  = 500000;                  // Borne haute de l'historique M1 lu. Historique insuffisant = REFUS BAVARD, jamais une mesure silencieusement tronquee.
input string HP_Horizons = "1,2,5,10,15,30,60,120"; // Horizons en MINUTES, separes par des VIRGULES, entiers uniquement. Tout jeton malforme ou double = REFUS BAVARD.
input datetime HP_DateFrom = D'1970.01.01';         // Debut de la periode mesuree (1970 = TOUT l'historique lu, comportement v1.01 bit-a-bit). Une fenetre n'est retenue que si SON OUVERTURE tombe dans [From, To].
input datetime HP_DateTo   = D'1970.01.01';         // Fin de la periode mesuree (1970 = TOUT l'historique lu). ⚠️ Borne l'OUVERTURE des fenetres, PAS leur fin : une fenetre a le droit de se terminer apres To (sinon H=120 perdrait 2 h de plus que H=1 et les colonnes ne seraient plus comparables).

//--- Échantillon indépendant minimal sous lequel un horizon est déclaré NON
//    CONCLUANT. ⚠️ Appliqué à l'équivalent NON CHEVAUCHANT
//    (used/H), pas au compte brut : les fenêtres glissantes partagent H−1
//    minutes sur H et ne sont pas des tirages indépendants (revue).
#define HP_MIN_WINDOWS   10000
//--- Pause : convention : >= 30 min entre deux barres M1.
#define HP_PAUSE_SECONDS 1800
#define HP_MAX_HORIZONS  32
//--- Sous ce taux de rétention, le biais de sélection est nommé sur la ligne.
#define HP_MIN_RETENTION 0.90

//+------------------------------------------------------------------+
//| Refus BAVARD — refus explicite, écrit ici pour que le script  |
//| reste DÉTACHABLE (aucun include externe).                        |
//+------------------------------------------------------------------+
void HP_Reject(const string param, const string value, const string expected, const string hint)
  {
   PrintFormat("SB [HORIZON] ⛔ REFUS : %s = %s — attendu %s. %s", param, value, expected, hint);
  }

//--- Quantile d'un tableau DÉJÀ TRIÉ (interpolation linéaire).
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

//--- ArrayResize vérifié : un échec d'allocation doit produire un REFUS
//    BAVARD, jamais un « array out of range » (revue).
bool HP_Resize(double &arr[], const int n, const string what)
  {
   if(ArrayResize(arr, n) == n)
      return true;
   HP_Reject("HP_MaxBars", IntegerToString(n), "une taille de tableau tenant en memoire",
             "Allocation refusee pour « " + what + " » — reduire HP_MaxBars.");
   return false;
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   //================================================================
   //  0. VALIDATION — refus bavards, jamais de silence.
   //================================================================
   if(HP_Lots <= 0.0)
     {
      HP_Reject("HP_Lots", DoubleToString(HP_Lots, 2), "> 0",
                "Taille de reference pour l'affichage en $ (aucun ratio n'en depend).");
      return;
     }
   if(HP_MaxBars < 1000)
     {
      HP_Reject("HP_MaxBars", IntegerToString(HP_MaxBars), ">= 1000",
                "Sous 1000 barres M1, aucun horizon ne peut rendre un echantillon lisible.");
      return;
     }
   string parts[];
   const int nParts = StringSplit(HP_Horizons, ',', parts);
   if(nParts <= 0)
     {
      HP_Reject("HP_Horizons", "\"" + HP_Horizons + "\"", "des entiers separes par des VIRGULES",
                "Exemple : \"1,2,5,10,15,30,60,120\" (minutes). Un autre separateur (;, espace) n'est "
                "PAS reconnu et rendrait un seul jeton.");
      return;
     }
   if(nParts > HP_MAX_HORIZONS)
     {
      HP_Reject("HP_Horizons", IntegerToString(nParts) + " horizons",
                "<= " + IntegerToString(HP_MAX_HORIZONS),
                "Borne dure du script — au-dela, la lecture du tableau n'a plus de sens.");
      return;
     }
   int hor[HP_MAX_HORIZONS];
   int nHor = 0;
   for(int i = 0; i < nParts; i++)
     {
      string t = parts[i];
      StringTrimLeft(t);
      StringTrimRight(t);
      // VALIDATION STRICTE, caractère par caractère (revue) : StringToInteger
      // suit la sémantique atol — « 5 min », « 1.5 », « 1;2;5 » rendaient des
      // valeurs plausibles EN SILENCE, et un jeton vide était sauté sans rien
      // dire. Un script de MESURE ne devine pas ce que l'utilisateur voulait.
      const int len = StringLen(t);
      if(len < 1 || len > 9)
        {
         HP_Reject("HP_Horizons", "jeton n°" + IntegerToString(i + 1) + " = \"" + t + "\"",
                   "1 a 9 chiffres",
                   "Jeton vide ou trop long — verifier les virgules de la liste.");
         return;
        }
      for(int c = 0; c < len; c++)
        {
         const ushort ch = StringGetCharacter(t, c);
         if(ch < '0' || ch > '9')
           {
            HP_Reject("HP_Horizons", "jeton n°" + IntegerToString(i + 1) + " = \"" + t + "\"",
                      "des CHIFFRES uniquement (minutes entieres)",
                      "Ni decimale, ni unite, ni autre separateur : \"5 min\", \"1.5\" et \"1;2\" "
                      "seraient interpretes a tort.");
            return;
           }
        }
      const int h = (int)StringToInteger(t);
      if(h <= 0)
        {
         HP_Reject("HP_Horizons", "\"" + t + "\"", "entier > 0 (minutes)",
                   "Un horizon nul n'a pas de sens.");
         return;
        }
      for(int j = 0; j < nHor; j++)
         if(hor[j] == h)
           {
            HP_Reject("HP_Horizons", "horizon " + IntegerToString(h) + " en DOUBLE",
                      "des horizons distincts",
                      "Une ligne repetee ne mesure rien de plus et fausse la lecture du tableau.");
            return;
           }
      hor[nHor++] = h;
     }
   if(nHor == 0)
     {
      HP_Reject("HP_Horizons", "\"" + HP_Horizons + "\"", "au moins un horizon valide",
                "La liste ne contient aucun entier exploitable.");
      return;
     }
   //--- v1.02 : les bornes de date. 0 (ou 1970) = borne absente.
   if(HP_DateFrom > 0 && HP_DateTo > 0 && HP_DateFrom >= HP_DateTo)
     {
      HP_Reject("HP_DateFrom/HP_DateTo",
                TimeToString(HP_DateFrom, TIME_DATE|TIME_MINUTES) + " / " +
                TimeToString(HP_DateTo, TIME_DATE|TIME_MINUTES),
                "HP_DateFrom STRICTEMENT anterieure a HP_DateTo",
                "Une periode vide ou inversee ne mesurerait rien. Laisser les deux a 1970 pour "
                "prendre TOUT l'historique lu.");
      return;
     }

   //================================================================
   //  1. L'INSTRUMENT. Le SYMBOLE vient du graphique ; la PÉRIODE est
   //     ignorée : les horizons sont en MINUTES, donc mesure sur M1.
   //================================================================
   const string sym = _Symbol;
   if(_Period != PERIOD_M1)
      PrintFormat("SB [HORIZON] ⚠️ graphique en %s : les horizons sont en MINUTES, la mesure se fait donc "
                  "sur M1 — seul le SYMBOLE (%s) est repris du graphique.",
                  EnumToString((ENUM_TIMEFRAMES)_Period), sym);

   const double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   const double tickSize  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   const double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0)
     {
      PrintFormat("SB [HORIZON] ⛔ fiche symbole INEXPLOITABLE (%s) : tick_value %.5f, tick_size %.5f, "
                  "point %.5f — impossible de convertir des points en $. Mesure abandonnee.",
                  sym, tickValue, tickSize, point);
      return;
     }
   const double valuePerPoint = tickValue * (point / tickSize) * HP_Lots;

   //================================================================
   //  2. L'HISTORIQUE M1.
   //================================================================
   const int available = Bars(sym, PERIOD_M1);
   int want = (int)MathMin((double)HP_MaxBars, (double)available);
   int hMax = 0;
   for(int i = 0; i < nHor; i++)
      if(hor[i] > hMax)
         hMax = hor[i];
   if(want < hMax + 100)
     {
      PrintFormat("SB [HORIZON] ⛔ HISTORIQUE INSUFFISANT : %d barre(s) M1 disponible(s) sur %s (borne "
                  "HP_MaxBars %d), il en faut au moins %d pour l'horizon le plus long (%d min). "
                  "Charger l'historique M1 (graphique %s en M1, defiler vers le passe) puis relancer. "
                  "Le telechargement est ASYNCHRONE : un second lancement peut suffire. JAMAIS une "
                  "mesure silencieusement tronquee.",
                  available, sym, HP_MaxBars, hMax + 100, hMax, sym);
      return;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, false);        // index 0 = le PLUS ANCIEN (explicite, jamais supposé)
   // ⚠️ LECTURE DEPUIS LA POSITION 1 (revue) : la barre 0 est EN FORMATION —
   // son close bouge, son spread aussi. L'inclure rendait la dernière fenêtre,
   // la plage de dates ET la distribution de spread instables d'un lancement
   // à l'autre.
   const int got = CopyRates(sym, PERIOD_M1, 1, want, rates);
   if(got <= 0)
     {
      PrintFormat("SB [HORIZON] ⛔ CopyRates a rendu %d pour %d barre(s) M1 demandee(s) sur %s "
                  "(erreur %d) — mesure abandonnee. Le telechargement M1 est asynchrone : relancer.",
                  got, want, sym, GetLastError());
      return;
     }
   if(got < hMax + 100)
     {
      PrintFormat("SB [HORIZON] ⛔ CopyRates n'a servi que %d barre(s) sur %d demandee(s) — moins que les "
                  "%d requises pour l'horizon le plus long (%d min). Le telechargement M1 est ASYNCHRONE : "
                  "relancer apres chargement. Mesure abandonnee (jamais tronquee en silence).",
                  got, want, hMax + 100, hMax);
      return;
     }
   if(got < want)
      PrintFormat("SB [HORIZON] ⚠️ %d barre(s) M1 obtenue(s) sur %d demandee(s) : le terminal borne "
                  "l'historique servi. La mesure porte sur ce qui a ETE lu.", got, want);

   PrintFormat("═══ SB HORIZON PROBE v1.02 — %s, %d barre(s) M1 du %s au %s (barre en formation EXCLUE) ═══",
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
   PrintFormat("Horizons RETENUS (%d, en minutes) : %s — liste republiee pour verification a l'oeil.",
               nHor, horList);

   //================================================================
   //  2 bis. LA PÉRIODE MESURÉE (v1.02) — bornes sur l'OUVERTURE des
   //     fenêtres. Aux défauts (1970/1970) : iFrom = 0, iTo = got-1,
   //     donc TOUT l'historique lu, et le tableau est celui de la
   //     v1.01 bit à bit (les bornes de boucle coïncident).
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
      PrintFormat("SB [HORIZON] ⛔ AUCUNE barre M1 dans la periode demandee [%s ; %s] : l'historique lu "
                  "va du %s au %s. Aucune fenetre ne peut s'ouvrir dans cet intervalle — jamais un "
                  "tableau vide en silence. Mesure abandonnee.",
                  (HP_DateFrom > 0 ? TimeToString(HP_DateFrom, TIME_DATE|TIME_MINUTES) : "debut"),
                  (HP_DateTo   > 0 ? TimeToString(HP_DateTo,   TIME_DATE|TIME_MINUTES) : "fin"),
                  TimeToString(rates[0].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES));
      return;
     }
   //--- Au moins UNE fenêtre doit pouvoir s'ouvrir, pour le plus COURT
   //    horizon : sinon le tableau serait vide ligne après ligne. (iFrom <=
   //    iTo est DÉJÀ garanti par le refus ci-dessus : la seule impossibilité
   //    restante est le manque de barres APRÈS l'ouverture — la seconde
   //    condition d'origine en était l'exact doublon, retirée en revue.)
   if(iFrom + hMin >= got)
     {
      PrintFormat("SB [HORIZON] ⛔ AUCUNE fenetre exploitable dans la periode demandee : %d barre(s) "
                  "retenue(s) [%s ; %s], et il faut au moins %d barre(s) apres l'ouverture pour le plus "
                  "court horizon (%d min) — l'historique s'arrete le %s. Mesure abandonnee.",
                  iTo - iFrom + 1,
                  TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[iTo].time, TIME_DATE|TIME_MINUTES),
                  hMin, hMin, TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES));
      return;
     }
   const bool ranged = (HP_DateFrom > 0 || HP_DateTo > 0);
   if(ranged)
      PrintFormat("⚠️ REFERENTIEL HORAIRE : les bornes de date sont comparees a l'heure du SERVEUR "
                  "(%s, decalage actuel GMT%+d) — la MEME date saisie sur un autre courtier ne designe "
                  "PAS le meme instant. C'est le referentiel de rates[].time, celui de tout le script.",
                  AccountInfoString(ACCOUNT_SERVER),
                  (int)((TimeTradeServer() - TimeGMT()) / 3600));
   if(!ranged)
      PrintFormat("PERIODE MESUREE : TOUT l'historique lu (bornes de date au defaut) — du %s au %s, "
                  "%d barre(s).",
                  TimeToString(rates[0].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES), got);
   else
     {
      PrintFormat("PERIODE MESUREE — DEMANDEE : [%s ; %s] | REELLEMENT OBTENUE : [%s ; %s], %d barre(s) "
                  "d'ouverture retenues sur %d lues. ⚠️ Ces bornes portent sur l'OUVERTURE des fenetres : "
                  "une fenetre a le droit de SE TERMINER apres la borne de fin (sinon H=%d perdrait "
                  "%d min de plus que H=%d et les colonnes ne seraient plus comparables).",
                  (HP_DateFrom > 0 ? TimeToString(HP_DateFrom, TIME_DATE|TIME_MINUTES) : "debut de l'historique"),
                  (HP_DateTo   > 0 ? TimeToString(HP_DateTo,   TIME_DATE|TIME_MINUTES) : "fin de l'historique"),
                  TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[iTo].time,   TIME_DATE|TIME_MINUTES),
                  iTo - iFrom + 1, got, hMax, hMax - hMin, hMin);
      //--- ⚠️ LA DEMANDE N'EST PAS COUVERTE : ça CRIE, ça ne se tronque
      //    pas en silence (le motif même de cette version : un premier run
      //    avait mesuré sept semaines en croyant mesurer deux ans).
      if(HP_DateFrom > 0 && HP_DateFrom < rates[0].time)
        {
         // ⚠️ MINUTES DE CALENDRIER, pas barres : le marché ne cote pas en
         // continu, donc c'est une BORNE HAUTE du nombre de barres absentes
         // (« au minimum » disait l'inverse — revue). L'estimation par la
         // densité RÉELLEMENT observée est publiée à côté.
         const long missMin = (long)(rates[0].time - HP_DateFrom) / 60;
         const long span    = (long)(rates[got - 1].time - rates[0].time);
         const double dens  = (span > 0 ? (double)got / (span / 60.0) : 0.0);   // barres par minute calendaire
         PrintFormat("⛔ DEBUT NON COUVERT : la periode demandee commence le %s, mais l'historique LU "
                     "ne remonte qu'au %s — %d minute(s) de CALENDRIER d'ecart (BORNE HAUTE du nombre "
                     "de barres M1 absentes : les week-ends n'en portent aucune ; a la densite observee "
                     "de %.2f barre/min, l'ordre de grandeur est ~%d barres). La mesure porte sur une "
                     "periode PLUS COURTE que celle demandee — augmenter HP_MaxBars et/ou charger "
                     "l'historique M1 (graphique en M1, defiler vers le passe).",
                     TimeToString(HP_DateFrom, TIME_DATE|TIME_MINUTES),
                     TimeToString(rates[0].time, TIME_DATE|TIME_MINUTES),
                     (int)missMin, dens, (int)(missMin * dens));
        }
      if(HP_DateTo > 0 && HP_DateTo > rates[got - 1].time)
         PrintFormat("⛔ FIN NON COUVERTE : la periode demandee va jusqu'au %s, mais l'historique LU "
                     "s'arrete au %s. La mesure porte sur une periode PLUS COURTE que celle demandee.",
                     TimeToString(HP_DateTo, TIME_DATE|TIME_MINUTES),
                     TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES));
     }
   PrintFormat("Conversion : %.2f lot, tick_value %.5f / tick_size %.5f / point %.5f => %.5f $ par point. "
               "⚠️ Valeur du tick lue MAINTENANT (devise du compte %s) et appliquee a tout l'historique : "
               "la colonne $ est une valorisation ACTUELLE d'amplitudes passees. Les RATIOS sont en POINTS "
               "et n'en dependent PAS.",
               HP_Lots, tickValue, tickSize, point, valuePerPoint,
               AccountInfoString(ACCOUNT_CURRENCY));

   //================================================================
   //  3. LE COÛT — le SPREAD OBSERVÉ. Barres à spread 0 comptées et
   //     écartées ; régime détecté (valeur modale, moitiés).
   //================================================================
   //--- v1.02 : la distribution est calculée SUR LA PÉRIODE RETENUE (iFrom..iTo)
   //    et non sur tout l'historique — le spread de 2024 n'est pas celui de
   //    2026, c'est l'objet même de la version. Aux défauts, iFrom = 0 et
   //    iTo = got-1 : les bornes coïncident avec la v1.01, bit à bit.
   const int nRange = iTo - iFrom + 1;
   double sp[];
   if(!HP_Resize(sp, nRange, "distribution du spread"))
      return;
   int nZero = 0, nSp = 0;
   for(int i = iFrom; i <= iTo; i++)
     {
      if(rates[i].spread <= 0)
        {
         nZero++;
         continue;                        // écarté de la médiane, compté et DIT
        }
      sp[nSp++] = (double)rates[i].spread;
     }
   if(nSp == 0)
     {
      PrintFormat("SB [HORIZON] ⛔ AUCUNE barre ne porte de spread sur la periode mesuree (%d barres a "
                  "spread 0) : pas de cout observable — tout mouvement « depasserait » un cout de zero et "
                  "le tableau ne voudrait RIEN dire (symbole custom, ticks importes, testeur mal "
                  "configure). Mesure abandonnee.", nRange);
      return;
     }
   if(!HP_Resize(sp, nSp, "distribution du spread (compactee)"))
      return;
   ArraySort(sp);
   const double spMin = sp[0];
   const double spMed = HP_Quantile(sp, 0.50);
   const double spP90 = HP_Quantile(sp, 0.90);
   const double spMax = sp[nSp - 1];
   //--- LE COÛT A/R : traverser le spread une fois EST le coût complet d'un
   //    aller-retour au même prix. ARRONDI à l'entier de points (les prix sont
   //    sur la grille du point : un coût interpolé à 24,5 comparerait des
   //    entiers à une demi-unité, et la valeur publiée ne serait pas celle
   //    utilisée — revue). L'arrondi est DIT.
   const double costPts = MathRound(spMed);

   //--- ⛔ TEST DU COÛT NUL : INDÉPENDANT et EN PREMIER (revue, HIGH — il
   //    était en `else if` derrière le test de spread constant, donc
   //    INATTEIGNABLE dans le cas le plus fréquent : un historique
   //    entièrement à spread 0 imprimait « spread constant » et publiait
   //    quand même un tableau à coût nul, PLAFOND ~99 % partout).
   if(costPts <= 0.0)
     {
      PrintFormat("SB [HORIZON] ⛔ COUT MEDIAN NUL (mediane %.2f pt sur %d barre(s) a spread renseigne) : "
                  "aucun peage a franchir, le tableau ne voudrait RIEN dire. Mesure abandonnee.",
                  spMed, nSp);
      return;
     }

   PrintFormat("COUT A/R MESURE : spread MEDIAN observe %.2f pts (arrondi a %.0f pts pour la mesure) = "
               "%.2f $ pour %.2f lot. ⚠️ COMMISSION et SLIPPAGE NON inclus (la 1re jamais mesuree sur ce "
               "compte, le 2d non mesurable depuis des barres) : ce cout est un PLANCHER, et tout PLAFOND "
               "une borne haute OPTIMISTE.",
               spMed, costPts, costPts * valuePerPoint, HP_Lots);
   PrintFormat("Distribution du spread : min %.2f / mediane %.2f / p90 %.2f / max %.2f pts "
               "(en $ pour %.2f lot : %.2f / %.2f / %.2f / %.2f).",
               spMin, spMed, spP90, spMax, HP_Lots,
               spMin * valuePerPoint, spMed * valuePerPoint,
               spP90 * valuePerPoint, spMax * valuePerPoint);
   if(nZero > 0)
      PrintFormat("⚠️ %d barre(s) sur %d (%.1f%%) portent un spread NUL : ECARTEES du calcul de la mediane "
                  "(calculee sur %d barre(s) a spread renseigne). Un historique MIXTE signale une source "
                  "partiellement importee — la mediane ne decrit alors que la partie renseignee.",
                  nZero, nRange, 100.0 * nZero / nRange, nSp);
   //--- Régime : valeur MODALE et moitiés chronologiques (revue — min==max ne
   //    voyait pas un changement de régime en cours d'historique).
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
   //--- Moitiés CHRONOLOGIQUES de la période retenue (v1.02). Aux défauts,
   //    mid = 0 + got/2 : le découpage de la v1.01, à l'identique.
   const int mid = iFrom + nRange / 2;
   int n1 = 0, n2 = 0;
   if(!HP_Resize(h1, nRange / 2 + 1, "spread 1re moitie") ||
      !HP_Resize(h2, nRange - nRange / 2 + 1, "spread 2de moitie"))
      return;
   for(int i = iFrom; i <= iTo; i++)
     {
      if(rates[i].spread <= 0)
         continue;
      if(i < mid) h1[n1++] = (double)rates[i].spread;
      else        h2[n2++] = (double)rates[i].spread;
     }
   double med1 = 0.0, med2 = 0.0;
   if(n1 > 0) { HP_Resize(h1, n1, "spread 1re moitie"); ArraySort(h1); med1 = HP_Quantile(h1, 0.50); }
   if(n2 > 0) { HP_Resize(h2, n2, "spread 2de moitie"); ArraySort(h2); med2 = HP_Quantile(h2, 0.50); }
   // « n/a » explicite quand une moitié ne porte AUCUNE barre tarifée : 0,00
   // se lirait comme un spread MESURÉ à zéro — la valeur la plus optimiste
   // possible, à la place d'une valeur non définie (revue).
   const string med1Txt = (n1 > 0 ? StringFormat("%.2f", med1) : "n/a (0 barre a spread renseigne)");
   const string med2Txt = (n2 > 0 ? StringFormat("%.2f", med2) : "n/a (0 barre a spread renseigne)");
   PrintFormat("Regime du spread : valeur MODALE %.0f pts sur %.1f%% des barres ; mediane 1re moitie "
               "%s / 2de moitie %s pts.", modeVal, 100.0 * modeShare, med1Txt, med2Txt);
   bool costSuspect = false;
   // SOURCE MIXTE : une moitié entièrement non tarifée. Sans ce cas, l'alarme
   // « changement de régime » (qui exige med1 > 0 ET med2 > 0) était DÉSARMÉE
   // par la source mixte elle-même — précisément ce qu'elle devait attraper.
   if((n1 == 0) != (n2 == 0))
     {
      costSuspect = true;
      Print("⛔ SOURCE MIXTE : une moitie de la periode ne porte AUCUN spread renseigne (import a "
            "spread 0 d'un cote, live de l'autre) — le cout median ne decrit QUE l'autre moitie.");
     }
   if(spMin == spMax)
     {
      costSuspect = true;
      PrintFormat("⛔ SPREAD CONSTANT (%.0f pts sur les %d barres renseignees) : source en SPREAD FIXE. "
                  "Le cout de cette mesure est une CONSTANTE ARBITRAIRE, pas un cout observe.", spMin, nSp);
     }
   else if(modeShare > 0.90)
     {
      costSuspect = true;
      PrintFormat("⛔ SPREAD QUASI FIXE : %.1f%% des barres portent la meme valeur (%.0f pts). Le cout est "
                  "quasi une constante — meme reserve qu'un spread fixe.", 100.0 * modeShare, modeVal);
     }
   if(n1 > 0 && n2 > 0 && med1 > 0.0 && med2 > 0.0 &&
      (med2 / med1 > 2.0 || med1 / med2 > 2.0))
     {
      costSuspect = true;
      PrintFormat("⛔ CHANGEMENT DE REGIME : la mediane du spread passe de %.2f a %.2f pts entre les deux "
                  "moities de l'historique (facteur %.1f). Un cout MEDIAN GLOBAL ne decrit alors ni l'une "
                  "ni l'autre periode.", med1, med2, MathMax(med2 / med1, med1 / med2));
     }

   //================================================================
   //  4. PRÉ-CALCUL DES PAUSES — index de la dernière barre précédée
   //     d'un écart >= 30 min, en O(n) : sert à classer une exclusion
   //     sur LE PLUS GRAND ÉCART de la fenêtre et non sur l'excès
   //     cumulé (revue : aux longs horizons, 30 minutes manquantes
   //     éparpillées étaient étiquetées « pause »).
   //================================================================
   int lastPause[];
   if(ArrayResize(lastPause, got) != got)
     {
      HP_Reject("HP_MaxBars", IntegerToString(got), "une taille tenant en memoire",
                "Allocation refusee pour l'index des pauses — reduire HP_MaxBars.");
      return;
     }
   lastPause[0] = -1;
   for(int i = 1; i < got; i++)
      lastPause[i] = (((long)(rates[i].time - rates[i - 1].time) >= HP_PAUSE_SECONDS)
                        ? i : lastPause[i - 1]);

   //================================================================
   //  5. LE TABLEAU.
   //================================================================
   // Titre et pied de tableau CONDITIONNELS : en mode borné, « toutes les
   // fenetres de l'historique lu » serait FAUX (revue).
   if(ranged)
      PrintFormat("─── PLAFOND DE L'ORACLE, PAR HORIZON (fenetres OUVRANT dans [%s ; %s]) ───",
                  TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[iTo].time,   TIME_DATE|TIME_MINUTES));
   else
      Print("─── PLAFOND DE L'ORACLE, PAR HORIZON (toutes fenetres glissantes) ───");
   Print("★ LE JUGE DE RENTABILITE EST L'ESPERANCE (ampl. MOYENNE - cout) : un oracle a direction "
         "PARFAITE gagne (|d| - cout) sur chaque fenetre, il est donc rentable SSI moyenne(|d|) > cout. "
         "Le PLAFOND (part des fenetres ou |d| > cout) mesure autre chose : avec des queues epaisses "
         "(mediane << moyenne) un oracle peut etre tres rentable avec MOINS de la moitie des fenetres "
         "au-dessus du peage. La MARGE (PLAFOND - SEUIL) est publiee pour memoire mais "
         "soustrait DEUX TAUX DE NATURES DIFFERENTES : indicateur, jamais verdict.");
   Print("Fenetres GLISSANTES au pas de 1 min : elles se CHEVAUCHENT (H-1 minutes communes) et ne sont "
         "PAS des tirages independants — l'equivalent non chevauchant (~used/H) est publie et c'est LUI "
         "qui porte la regle des 10 000. Comptage STRICT : un mouvement EGAL au cout ne paie pas le "
         "peage et n'est pas compte. « ecart >= 30 min » / « ecart < 30 min » = ce qui est MESURE (une "
         "duree), pas la cause (le script ne distingue pas un week-end d'un trou de donnees).");

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
      // v1.02 : la dernière ouverture RÉELLEMENT mesurable pour CET horizon.
      // Elle dépend de H dès que la période touche la fin des données lues —
      // l'inégalité que la borne « fin libre » évite du côté To revient par
      // le côté données, et elle est DITE sur la ligne (revue).
      const int iLast = (int)MathMin((double)iTo, (double)(got - 1 - H));

      // v1.02 : l'OUVERTURE i est bornée à la période [iFrom ; iTo] ; la FIN
      // (i+H) n'est bornée que par les données — une fenêtre a le droit de se
      // terminer après HP_DateTo (sinon les horizons longs seraient tronqués
      // davantage et les colonnes cesseraient d'être comparables). Aux
      // défauts, iFrom = 0 et iTo = got-1 : la condition binding redevient
      // « i + H < got », exactement la boucle de la v1.01.
      for(int i = iFrom; i <= iTo && i + H < got; i++)
        {
         // Fenêtre retenue SSI elle dure EXACTEMENT H minutes.
         const long elapsed = (long)(rates[i + H].time - rates[i].time);
         if(elapsed != need)
           {
            // Classement sur LE PLUS GRAND ÉCART DANS la fenêtre.
            if(lastPause[i + H] > i) exclPause++;
            else                     exclMissing++;
            continue;
           }
         // Quantification EXPLICITE : les prix sont des multiples du point,
         // l'arrondi est exact — il supprime la loterie d'arrondi binaire sur
         // les fenêtres exactement au coût (revue).
         const double d = MathRound(MathAbs(rates[i + H].close - rates[i].close) / point);
         amp[used] = d;
         sumAmp   += d;
         if(d > costPts)                        // coût MÉDIAN (strict)
            over++;
         else if(d == costPts)
            atCost++;
         // COÛT DE LA FENÊTRE : uniquement sur les ouvertures TARIFÉES —
         // une barre à spread 0 (historique importé) donnerait un péage de
         // ZÉRO et ferait passer ~toutes ses fenêtres, gonflant la colonne
         // qui sert justement à chiffrer le biais du coût constant (revue,
         // HIGH : la contamination se serait lue comme une corrélation
         // spread/mouvement).
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
         // CAUSE STRUCTURELLE, distinguée du cas « tout a été écarté » : aucune
         // fenêtre n'a même pu S'OUVRIR — la période commence trop près de la
         // fin des données lues pour cet horizon (revue).
         PrintFormat("H=%3d min | ⛔ AUCUNE fenetre ne peut S'OUVRIR : la periode debute le %s et "
                     "l'historique lu s'arrete le %s — il faut %d min apres l'ouverture. Cause "
                     "STRUCTURELLE : aucune fenetre n'a ete ECARTEE, il n'y en avait aucune.",
                     H, TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                     TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES), H);
         continue;
        }
      if(used == 0)
        {
         PrintFormat("H=%3d min | ⛔ AUCUNE fenetre exploitable sur %d (ecart >= 30 min : %d, ecart < 30 "
                     "min : %d) — cet horizon ne mesure RIEN.", H, seen, exclPause, exclMissing);
         continue;
        }

      double ampUsed[];
      if(!HP_Resize(ampUsed, used, "amplitudes retenues"))
         return;
      ArrayCopy(ampUsed, amp, 0, 0, used);
      ArraySort(ampUsed);
      const double ampMed  = HP_Quantile(ampUsed, 0.50);
      const double ampMean = sumAmp / used;

      const double ceiling    = (double)over / used;      // PLAFOND, coût médian
      // PLAFOND au coût de la fenêtre : rapporté aux seules ouvertures
      // TARIFÉES, et « n/a » si aucune (jamais un nombre à la place d'une
      // valeur non définie).
      const string ceilWinTxt = (usedWin > 0
                                   ? StringFormat("%5.1f%%", 100.0 * overWin / usedWin)
                                   : "  n/a");
      const double expect     = ampMean - costPts;        // ★ ESPÉRANCE DE L'ORACLE (points)
      const int    indep      = used / H;                 // équivalent NON chevauchant
      const double retention  = (double)used / seen;

      //--- Ratio et seuil : « n/a » explicite si l'amplitude est nulle — un
      //    instrument de mesure ne substitue JAMAIS un nombre (0,0, qui est
      //    ici la valeur la PLUS optimiste) à une valeur non définie (revue).
      const string ratioTxt = (ampMed > 0.0
                                 ? StringFormat("%5.1f%%", 100.0 * costPts / ampMed)
                                 : "  n/a (ampl. mediane NULLE)");
      string seuilTxt, margeTxt;
      if(ampMean > 0.0)
        {
         const double thresh = 0.5 + costPts / (2.0 * ampMean);
         seuilTxt = (thresh > 1.0
                       ? StringFormat("%5.1f%% ⛔ INATTEIGNABLE (> 100 %% : meme une direction PARFAITE "
                                      "ne paie pas le peage)", 100.0 * thresh)
                       : StringFormat("%5.1f%%", 100.0 * thresh));
         margeTxt = StringFormat("%+6.1f pts de %%", 100.0 * (ceiling - thresh));
        }
      else
        {
         seuilTxt = "n/a"; margeTxt = "n/a (aucune amplitude sur cet horizon)";
        }

      PrintFormat("H=%3d min | fenetres %7d (~%6d non chevauchantes) | retention %5.1f%% "
                  "[ecart >= 30 min %6d / ecart < 30 min %6d] | PLAFOND %5.1f%% (cout median) / %s "
                  "(cout de la fenetre, sur %d ouverture(s) a spread renseigne) | ampl. mediane %7.0f pts "
                  "(%8.2f $), moyenne %7.0f pts | cout/ampl.med %s | ★ ESPERANCE ORACLE %+8.0f pts "
                  "(%+8.2f $) %s | SEUIL %s | MARGE %s%s%s%s%s",
                  H, used, indep, 100.0 * retention, exclPause, exclMissing,
                  100.0 * ceiling, ceilWinTxt, usedWin,
                  ampMed, ampMed * valuePerPoint, ampMean,
                  ratioTxt,
                  expect, expect * valuePerPoint,
                  (expect > 0.0 ? "(> 0 : une direction PARFAITE paie le peage)"
                                : "⛔ (<= 0 : meme une direction PARFAITE ne paie pas le peage)"),
                  seuilTxt, margeTxt,
                  (atCost > 0 ? StringFormat(" | %d fenetre(s) EXACTEMENT au cout (non comptees, strict)",
                                             atCost) : ""),
                  (indep < HP_MIN_WINDOWS
                     ? StringFormat(" | ⚠️ ~%d fenetres INDEPENDANTES (< %d) : NON CONCLUANT",
                                    indep, HP_MIN_WINDOWS) : ""),
                  (retention < HP_MIN_RETENTION
                     ? StringFormat(" | ⚠️ retention %.1f%% : les fenetres retenues sont celles SANS "
                                    "minute creuse, donc les plages les plus ACTIVES — amplitude et "
                                    "plafond biaises VERS LE HAUT", 100.0 * retention) : ""),
                  // v1.02 (revue) : la fin de la periode est tronquee par les
                  // DONNEES, et H fois plus fort pour l'horizon H — cette
                  // colonne ne couvre alors pas la meme fenetre de temps que
                  // les autres. Dit sur la ligne, jamais suppose.
                  // ⚠️ UNIQUEMENT en mode PERIODE : au defaut, iTo = got-1 et
                  // « les H dernieres barres n'ouvrent pas de fenetre » est la
                  // situation normale de tout historique — aucune borne n'a ete
                  // PUBLIEE qui pourrait mentir, et l'avertir a chaque ligne
                  // romprait l'identite du tableau avec la v1.01.
                  (ranged && iLast < iTo
                     ? StringFormat(" | ⚠️ derniere ouverture MESUREE %s (l'historique lu s'arrete le %s) "
                                    ": %d ouverture(s) de fin de periode non mesurables pour H=%d — "
                                    "comparaison inter-colonnes degradee sur la queue",
                                    TimeToString(rates[iLast].time, TIME_DATE|TIME_MINUTES),
                                    TimeToString(rates[got - 1].time, TIME_DATE|TIME_MINUTES),
                                    iTo - iLast, H) : ""));
     }

   if(costSuspect)
      Print("⛔ RAPPEL SOUS LE TABLEAU : le cout de cette passe est suspect (spread fixe, quasi fixe ou "
            "changement de regime — voir plus haut). TOUTES les lignes ci-dessus en dependent : elles ne "
            "mesurent pas un cout observe. Repeter ce rappel ici est volontaire — un lecteur qui ne lit "
            "que le tableau ne doit pas pouvoir rater l'information.");
   if(ranged)
      PrintFormat("═══ FIN — ce script MESURE, il n'optimise rien et ne trade rien. Aucune hypothese de "
                  "distribution : toutes les fenetres OUVRANT dans [%s ; %s] ont ete parcourues "
                  "(%d ouverture(s) candidates sur %d barre(s) lues). ═══",
                  TimeToString(rates[iFrom].time, TIME_DATE|TIME_MINUTES),
                  TimeToString(rates[iTo].time,   TIME_DATE|TIME_MINUTES), nRange, got);
   else
      Print("═══ FIN — ce script MESURE, il n'optimise rien et ne trade rien. Aucune hypothese de "
            "distribution : toutes les fenetres glissantes de l'historique lu ont ete parcourues. ═══");
  }
//+------------------------------------------------------------------+
