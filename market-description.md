# Fiche MQL5 Market — HorizonProbe

> ✅ **LES TROIS BLOQUANTS SONT LEVÉS — prêt à soumettre.**
> Traduction anglaise faite (48 appels de format vérifiés, 0 divergence) · `#property link`
> et `description` ajoutés · capture préparée (`market_screens/01-oracle-ceiling-per-horizon.png`,
> 1909×595, 137 Ko) · logos en 200/140/60.
>
> ⓘ **Le lien** : aucune adresse dans la description, elle vit sur le **profil MQL5** de JR
> — même règle que DataForge.

---

## Titre du produit (39 caractères)

```
HorizonProbe Holding Time Cost Analyzer
```

*(≤ 50 caractères, latin, première lettre majuscule, aucun numéro de version, aucun mot tout en majuscules.)*

## Catégorie

Utilities — **gratuit**.

---

## Description (anglais, à coller telle quelle)

```
HorizonProbe measures how the size of a price move compares with the cost of trading it, across several holding times, on your broker's own history and your broker's own spread.

It is a single script. It places no orders, reads no positions, and has no external dependency. Copy the one file into a terminal and run it on a chart.

THE QUESTION IT ANSWERS

The cost of a trade is paid once, whatever happens next. The move you are paid for is not fixed: over a longer holding time, the average move is larger. There is therefore a holding time below which the typical move does not cover the cost, and no directional accuracy can change that.

That threshold depends on the instrument, on the broker's spread, and on the period. It is usually estimated with a square-root-of-time rule and a normal distribution. Both assumptions understate large moves, which are exactly the ones that cover the cost. This script does not estimate it. It walks every sliding window in the history and counts.

WHAT IT PRINTS, FOR EACH HOLDING TIME YOU LIST

- The share of windows where the absolute move exceeds the median round-trip cost.

- The same share computed again, with each window judged at the spread actually observed at its own entry. The difference between the two numbers is a measurement, not a detail: on some instruments the spread widens exactly when the move is large, so a constant cost flatters the result.

- The average absolute move minus the cost. This is the quantity that decides whether a perfect direction would cover its costs, because such a series earns the move minus the cost on every window.

- The directional accuracy that would be required to cover costs, expressed as a percentage and compared with 100 percent.

- The number of windows retained, and their non-overlapping equivalent. Sliding windows share most of their content and are not independent observations, so the second number is the one that carries any sample-size consideration.

A READING NOTE THAT THE SCRIPT PRINTS ITSELF

The share of windows above the cost and the average move minus the cost measure different things. When the distribution has heavy tails, and the median is well below the mean, fewer than half the windows can exceed the cost while the average move still exceeds it comfortably. Reading the share as the conclusion is therefore systematically pessimistic, on precisely the instruments where this measurement is most useful.

The difference between the two rates is also printed, for reference, and it is labelled as an indicator rather than a conclusion, because it subtracts two quantities that do not have the same nature.

HOW IT BEHAVES

It reads M1 history and expresses holding times in minutes. A malformed or duplicated holding time, or an insufficient history, stops the run with a stated reason rather than producing a shortened measurement. Gaps are reported as measured durations; the script does not claim to distinguish a weekend from a missing block of data.

NOTES AND LIMITS

- The cost used is the round-trip spread. Commission and swap, where they apply to your account, are not included.
- It measures the instrument and its cost, not a strategy. A holding time that clears the cost is a necessary condition, never a sufficient one.
- Before running, set "Max bars in chart" to unlimited in the terminal options and scroll the chart back so that the history is loaded. A script reads what the terminal has cached, and the cap truncates without raising an error.
- The lot size input affects the currency display only. It changes no ratio.

The source code is published for reference.
```

---

## Notes de conformité (Part IV) — pourquoi le texte est écrit ainsi

- ✅ **Aucune promesse de gain.** Le mot *profit* n'apparaît pas ; on parle de *couvrir
  le coût*, ce qui est une grandeur mesurée et non un résultat promis.
- ✅ **Aucun superlatif**, aucun nom de courtier, aucun chiffre de performance.
- ✅ **Aucun résultat de backtest** — il n'y en a pas dans ce produit.
- ✅ **Aucun lien externe.** Phrases simples, ton neutre.
- ⚠️ Le résultat maison (« l'estimation disait 30 minutes, la mesure a dit 5 ») est
  **volontairement absent** de la fiche Market : sur un instrument nommé, il ressemblerait
  à une affirmation de performance. Il reste dans le README GitHub.
- ⚠️ Le mot *oracle* est retiré du texte Market : il est clair pour nous, obscur pour un
  acheteur. Remplacé par « une direction parfaite ».
