// Agent aluno.asl - Estratégia Sprague-Grundy Nim Misère
//
// Estratégia:
// 1. Pré-computa valores de Grundy (MEX) na fase +start para o conjunto
//    de possibleNumbers recebido em cada partida. Armazena como crenças grundy(N, G).
// 2. Usa Nim-sum sobre valores de Grundy (não tamanhos brutos) para
//    avaliar posições corretamente com movimentos restritos.
// 3. Busca jogada vencedora por curto-circuito (unificação de regras),
//    parando na primeira jogada válida encontrada.
// 4. Correção Misère: quando resta apenas 1 torre grande, ajusta para
//    deixar número ÍMPAR de torres unitárias ao oponente.
// 5. Fallback: quando em posição perdedora, stall (remove 1 pedra)
//    para maximizar turnos e chances de erro/timeout do oponente.

/* Crenças iniciais */
lastRemoved(0).

/* Objetivo inicial */
!start.

/* Plano inicial */
+!start : true <-
    .print("Agente pronto.").

// =============================================
// REGRAS (usam :- e & para conjunção lógica)
// =============================================

// XOR bit a bit de dois inteiros não-negativos
xor(0, B, B).
xor(A, 0, A) :- A > 0.
xor(A, B, R) :-
    A > 0 & B > 0 &
    BitA = A mod 2 &
    BitB = B mod 2 &
    Bit  = (BitA + BitB) mod 2 &
    A2   = (A - BitA) / 2 &
    B2   = (B - BitB) / 2 &
    xor(A2, B2, R2) &
    R    = R2 * 2 + Bit.

// XOR acumulado de uma lista de inteiros
listXor([], 0).
listXor([H|T], R) :-
    listXor(T, RT) &
    xor(H, RT, R).

// Valor de Grundy com fallback para tamanho bruto
// (caso a tabela não cubra um tamanho após adição via -1)
gVal(S, G) :- grundy(S, G).
gVal(S, S) :- not grundy(S, _).

// Endgame: todas as torres têm no máximo 1 pedra
allSmall :- not(tower(_, S) & S > 1).

// Regra para jogada de remoção vencedora (short-circuit via backtracking)
// Busca uma jogada que zere o Nim-Sum.
// OTIMIZADO: Força 'possibleNumber' primeiro e filtra as torres pelo tamanho (P >= K)
// Isso evita que o Jason faça backtrack em milhares de combinações impossíveis.
winningRemoval(GNimSum, T, K) :-
    possibleNumber(K) &
    tower(T, P) & P >= K &
    gVal(P, GOld) &
    gVal(P - K, GNew) &
    xor(GOld, GNimSum, Target) &
    GNew == Target.

// Regra para jogada -1 (adição) vencedora
// Verifica se adicionar floor(lastRemoved/2) a alguma torre zera o nim-sum
winningAdd(GNimSum, T) :-
    lastRemoved(LR) & LR > 1 &
    Add = (LR - LR mod 2) / 2 &
    tower(T, P) &
    NewP = P + Add &
    gVal(P, GOld) &
    gVal(NewP, GNew) &
    xor(GOld, GNimSum, Target) &
    GNew == Target.

// =============================================
// INÍCIO DO JOGO: Pré-computar valores de Grundy
// =============================================

// Quando +start é percebido, pré-computa a tabela de Grundy
// antes do primeiro round (há 0.4s de janela)
+start <-
    -lastRemoved(_);
    +lastRemoved(0);
    !precompute.

+!precompute <-
    .findall(S, tower(_, S), Sizes);
    .max(Sizes, MaxSize);
    .findall(K, possibleNumber(K), PNums);
    .max(PNums, MaxPN);
    Buffer = (MaxPN - MaxPN mod 2) / 2;
    Limit = MaxSize + Buffer + 10;
    .abolish(grundy(_, _));
    +grundy(0, 0);
    !computeLoop(1, Limit).

// Fallback: se precompute falhar, continuar sem tabela (gVal usa fallback)
-!precompute <-
    .print("Aviso: falha na pre-computacao de Grundy. Usando fallback.").

// Computação iterativa bottom-up de G(1) até G(Limit)
+!computeLoop(N, Max) : N > Max.
+!computeLoop(N, Max) : N <= Max <-
    .findall(G, (possibleNumber(K) & K <= N & NK = N - K & grundy(NK, G)), Reach);
    !mex(Reach, 0, Val);
    +grundy(N, Val);
    !computeLoop(N + 1, Max).

// MEX: menor inteiro não-negativo que NÃO está no conjunto
+!mex(Set, C, Result) : .member(C, Set) <-
    !mex(Set, C + 1, Result).
+!mex(Set, C, C) : not .member(C, Set).

// =============================================
// TURNO
// =============================================

// Meu turno: executar jogada
+round(_, WhoPlays) : .my_name(Me) & .term2string(Me, WhoPlays) <-
    !doMove.

// Não é meu turno: não fazer nada
+round(_, WhoPlays) : .my_name(Me) & .term2string(Me, MeStr) & MeStr \== WhoPlays.

// =============================================
// LÓGICA PRINCIPAL DE JOGADA
// =============================================

+!doMove <-
    !pickMove(T, S);
    play(T, S);
    if (S == -1) {
        -+lastRemoved(0)
    } else {
        -+lastRemoved(S)
    }.

// Rede de segurança: se qualquer plano falhar, jogar safe
-!doMove <-
    ?tower(T, P) & P > 0;
    play(T, 1);
    -+lastRemoved(1).

// =============================================
// SELEÇÃO DE JOGADA
// =============================================

// ENDGAME: todas as torres têm 0 ou 1 pedra
+!pickMove(T, S) : allSmall <-
    .findall(Tid, tower(Tid, 1), OneL);
    .length(OneL, OneCount);
    !endgame(OneCount, T, S).

// Se houver um número PAR de torres unitárias (Vitória no Misère):
// Apenas remova 1 pedra. Deixa um número ÍMPAR para o oponente.
+!endgame(OneCount, T, 1) : OneCount mod 2 == 0 <-
    ?tower(T, 1);
    .print(">>> ENDGAME (WINNING): Numero PAR de torres de 1 pedra. Tirando a torre ", T, " para prender o oponente.").

// Se houver um número ÍMPAR de torres unitárias (Derrota no Misère) 
// E podemos adicionar pedras (Hail Mary):
// Adiciona para quebrar o estado allSmall e forçar erro no oponente.
+!endgame(OneCount, T, -1) : OneCount mod 2 == 1 & lastRemoved(LR) & LR > 1 <-
    .print(">>> HAIL MARY ENDGAME! Numero IMPAR. Adicionando pedras na torre ", T, " para quebrar o Misere.");
    ?tower(T, 1).

// Se houver número ÍMPAR e NÃO podemos adicionar pedras: Stall/Aceitar derrota.
+!endgame(OneCount, T, 1) : OneCount mod 2 == 1 <-
    ?tower(T, 1);
    .print(">>> ENDGAME (LOSING): Numero IMPAR. Sem adicao possivel. Fim de jogo iminente.").

// JOGO NORMAL: calcular nim-sum e decidir estratégia
+!pickMove(T, S) <-
    !getNimSum(GNimSum);
    .findall(Tid, (tower(Tid, P) & P > 1), BigL);
    .length(BigL, BigCount);
    .findall(Tid2, tower(Tid2, 1), OneL);
    .length(OneL, OneCount);
    !strategy(GNimSum, BigCount, OneCount, T, S).

// Calcula Nim-sum dos valores de Grundy de todas as torres
+!getNimSum(Result) <-
    .findall(G, (tower(_, S) & gVal(S, G)), GVals);
    ?listXor(GVals, Result).

// =============================================
// ESTRATÉGIA POR CASO
// =============================================

// Caso 1: apenas 1 torre grande → correção Misère obrigatória
+!strategy(_, 1, OneCount, T, S) <-
    ?tower(T, P) & P > 1;
    .print(">>> MISERE ENGAGED! 1 Torre grande restante. Reduzindo torre ", T, " com ", P, " pedras.");
    !misere(P, OneCount, S).

// Caso 2: Grundy nim-sum ≠ 0 → posição vencedora, buscar jogada ótima
+!strategy(GNimSum, _, _, T, S) : GNimSum \== 0 <-
    !findWin(GNimSum, T, S);
    .print(">>> ATACANDO! Nim-Sum = ", GNimSum, " | Removendo ", S, " da torre ", T, ".").

// ---> NOVO Caso 2.5: MILAGRE DE PARIDADE (Polarity Flip) <---
// O Nim-Sum é 0, mas conseguimos adicionar pedras e manter o Nim-Sum em 0!
+!strategy(0, _, _, T, S) : winningAdd(0, T) <-
    .print(">>> POLARITY FLIP! Nim-Sum = 0 | Adicionando pedras na torre ", T, " para roubar o turno!");
    S = -1.

// Caso 3: Grundy nim-sum = 0 e sem milagre → stall com 1 pedra na MAIOR torre
+!strategy(0, _, _, T, 1) <-
    .findall(P, tower(_, P), Sizes);
    .max(Sizes, MaxP);
    ?tower(T, MaxP);
    .print(">>> DEFENDENDO. Nim-Sum = 0 | Fazendo STALL tirando 1 da maior torre (Torre ", T, " com ", MaxP, " pedras).").

// =============================================
// CORREÇÃO MISÈRE (1 torre grande restante)
// =============================================

// OneCount par → reduzir torre grande para 1 pedra
// Resultado: OneCount+1 (ímpar) torres unitárias para o oponente → oponente perde
+!misere(P, OneCount, S) : OneCount mod 2 == 0 <-
    Needed = P - 1;
    if (Needed > 0 & possibleNumber(Needed)) {
        S = Needed
    } else {
        // Não conseguimos reduzir para 1 exatamente. Stall.
        S = 1
    }.

// OneCount ímpar → remover todas as pedras da torre grande
// Resultado: OneCount (ímpar) torres unitárias para o oponente → oponente perde
+!misere(P, OneCount, S) : OneCount mod 2 == 1 <-
    if (possibleNumber(P)) {
        S = P
    } else {
        // Não podemos remover tudo. Evitar deixar exatamente 1 pedra
        // (inverteria a paridade e daria a vitória ao oponente).
        Avoid = P - 1;
        .findall(X, (possibleNumber(X) & X <= P & X \== Avoid), Safe);
        if (Safe \== []) {
            .max(Safe, S)
        } else {
            // Forçados a situação ruim, stall
            S = 1
        }
    }.

// =============================================
// BUSCA DE JOGADA VENCEDORA (short-circuit)
// Usa regras no contexto: Jason para no primeiro match
// =============================================

// Opção A: remoção ótima que zera o Grundy nim-sum (preferido para acelerar a vitória)
+!findWin(GNimSum, T, S) : winningRemoval(GNimSum, T, S) <- true.

// Opção B: usar -1 (adicionar pedras) se zera o Grundy nim-sum (secundário)
+!findWin(GNimSum, T, -1) : winningAdd(GNimSum, T) <- true.

// Opção C: restrições impedem jogada ótima → stall
+!findWin(_, T, 1) <-
    ?tower(T, P) & P > 0.


{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }

// uncomment the include below to have an agent compliant with its organisation
//{ include("$moise/asl/org-obedient.asl") }
