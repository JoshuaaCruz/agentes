// Agent sample_agent in project stones

/* Initial beliefs and rules */

/* Initial goals */

!start.

/* Plans */

+!start : true
    <- .print("hello world.");
       .date(Y,M,D); .time(H,Min,Sec,MilSec); // get current date & time
       +started(Y,M,D,H,Min,Sec).             // add a new belief

/* Percepts */

+start: .my_name(Me) & .term2string(Me, MeStr) & player(MeStr) <- 
    .print("Percebi que o jogo iniciou e sou um jogador.").

+round(N, WhoPlays): .my_name(Me) & .term2string(Me, WhoPlays) <- /*I'm the current player*/
    .print("It's round ", N, " I'm the player");
    
    // play(1,1). /*Você vai precisar modificar aqui, na hora de escolher qual torre e quantas pedras você quer tirar dela.*/
    ?tower(T, S) & S > 0;
    play(T,1).

+round(N, WhoPlays): .my_name(Me) & .term2string(Me, MeStr) & MeStr \== WhoPlays <- true. /*I'm NOT the current player*/

{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }

// uncomment the include below to have an agent compliant with its organisation
//{ include("$moise/asl/org-obedient.asl") }
