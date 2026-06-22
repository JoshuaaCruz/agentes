// Agent alunoBurro
// This agent plays chaotically to test the opponent's ability to capitalize on mistakes.

lastRemoved(0).
+start <- -lastRemoved(_); +lastRemoved(0).

+round(_, A) : .my_name(Me) & .term2string(Me, A) <-
    !makeDumbMove.

// Try to take 3 stones if possible to speed up the game slightly
+!makeDumbMove : tower(T, S) & S >= 3 <- 
    play(T, 3); 
    -+lastRemoved(3).

// Otherwise just take 1
+!makeDumbMove : tower(T, S) & S > 0 <- 
    play(T, 1); 
    -+lastRemoved(1).

// Fallback in case of emergency
-!makeDumbMove <- 
    ?tower(T, S) & S > 0;
    play(T, 1);
    -+lastRemoved(1).

// Ignore when it is not my turn
+round(N, WhoPlays): .my_name(Me) & .term2string(Me, MeStr) & MeStr \== WhoPlays <- true.

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }
