// CArtAgO artifact code for project stones

package example;

import java.util.ArrayList;
import java.util.Set;
import java.util.HashSet;
import java.util.Map;
import java.util.HashMap;

import cartago.*;

public class Mesa extends Artifact {
	private ArrayList<Integer> towers;
	private ArrayList<String> players = new ArrayList();
	private int curPlayerId;
	private int gameStatus = 0; //0 Not started 
	private boolean printlogs = false;
	private Set<Integer> possibleNumbers = new HashSet();
	private Map<String,Integer> lastPlay = new HashMap();

	void init(int players) {
		defineObsProperty("totalPlayers", players);
	}

	@OPERATION
	void reset() {
		if (getCurrentOpAgentId().getAgentName().equals("judge")) {
			gameStatus = 0;
			if (printlogs)
				System.out.println("Reset called!");

			if (towers != null) {
				for (int i = 1; i < towers.size(); i++) {
					removeObsPropertyByTemplate("tower", i, towers.get(i));
				}
				towers = null;
			}
			if (players != null) {
				for (String ag : players) {
					removeObsPropertyByTemplate("player", ag);
				}
				players.clear();
			}
			ObsProperty prop = getObsProperty("towers");
			if (prop != null) {
				prop.updateValue(0);
			} else {
				defineObsProperty("towers", 0);
			}
			prop = getObsProperty("round");
			if (prop != null)
				removeObsProperty("round");

			if (possibleNumbers != null) {
				for (Integer x : possibleNumbers) {
					removeObsPropertyByTemplate("possibleNumber", x);
				}
				possibleNumbers.clear();
			}
			if (lastPlay != null) {
				lastPlay.clear();
			}
		} else {
			defineObsProperty("violation", getCurrentOpAgentId().getAgentName(), "Bad call reset");
		}
	}

	@OPERATION
	void setAmountTowers(int totalTowers) {
		if (getCurrentOpAgentId().getAgentName().equals("judge")) {
			towers = new ArrayList<Integer>(totalTowers+1);
			for (int i = 0; i <= totalTowers; i++) {
				towers.add(0);
			}
			if (printlogs)
				System.out.println("setAmountTowers called with " + totalTowers + " Size " + towers.size());
			ObsProperty prop = getObsProperty("towers");
			prop.updateValue(totalTowers);
		} else {
			defineObsProperty("violation", getCurrentOpAgentId().getAgentName(), "Bad call setAmountTowers");
		}
	}

	@OPERATION
	void setAmountStonesTower(int idTower, int stones) {
		if (getCurrentOpAgentId().getAgentName().equals("judge")) {
			if (printlogs)
				System.out.println("setAmountStonesTower called with " + idTower + " " + stones);
			towers.set(idTower, stones);
			defineObsProperty("tower",idTower,stones);
		} else {
			defineObsProperty("violation", getCurrentOpAgentId().getAgentName(), "Bad call setAmountStones");
		}
	}

	@OPERATION
	void addPlayer(String agPlayer) {
		if (getCurrentOpAgentId().getAgentName().equals("judge")) {
			if (printlogs)
				System.out.println("addPlayer called with " + agPlayer);
			players.add(agPlayer);
			defineObsProperty("player", agPlayer);
			lastPlay.put(agPlayer,0);
		} else {
			defineObsProperty("violation", getCurrentOpAgentId().getAgentName(), "Bad call addPlayer");
		}
	}

	@OPERATION
	void setPossibleNumber(int x) {
		if (getCurrentOpAgentId().getAgentName().equals("judge")) {
			if (printlogs)
				System.out.println("added possible number called with " + x);
			
			possibleNumbers.add(x);
			defineObsProperty("possibleNumber", x);
		} else {
			defineObsProperty("violation", getCurrentOpAgentId().getAgentName(), "Bad call addPlayer");
		}
	}

	@OPERATION
	void play(int idTower, int stonesToRemove) {
		if (gameStatus == 0) return;
		if (getCurrentOpAgentId().getAgentName().equals(players.get(curPlayerId))) {
			if (idTower == 0 || idTower >= towers.size() || (stonesToRemove == 0 || stonesToRemove > towers.get(idTower) || !possibleNumbers.contains(stonesToRemove)) && (stonesToRemove != -1 || stonesToRemove == -1 && lastPlay.get(getCurrentOpAgentId().getAgentName()) <= 1)) {
				//System.out.println("Agent attempted to play on tower " + idTower + " with stones " + stonesToRemove + " and last play was " + lastPlay.get(getCurrentOpAgentId().getAgentName()));
				defineObsProperty("violation", getCurrentOpAgentId().getAgentName(), 
					"Bad call play: invalid parameters. " +
					"The agent tried to play on tower " + idTower + " with the parameter stones to remove = " + stonesToRemove + ", which is a " + (stonesToRemove == -1 || possibleNumbers.contains(stonesToRemove)?"valid":"invalid") + " amount to use" +
					". The tower currently have " + towers.get(idTower) + " stones " +
					". The last play of the agent was " + (lastPlay.get(getCurrentOpAgentId().getAgentName()) < 0 ? -1 : lastPlay.get(getCurrentOpAgentId().getAgentName()))
				);
			} else {
				System.out.println("Agent " + getCurrentOpAgentId().getAgentName() + " played on tower " + idTower + " remove " + stonesToRemove);

				ObsProperty prop = getObsPropertyByTemplate("tower", idTower, towers.get(idTower));

				if (stonesToRemove == -1) {
					stonesToRemove = - lastPlay.get(getCurrentOpAgentId().getAgentName()) / 2;
				}
				
				towers.set(idTower, towers.get(idTower)-stonesToRemove);
				prop.updateValues(idTower,towers.get(idTower));
				lastPlay.put(getCurrentOpAgentId().getAgentName(), stonesToRemove);

				boolean hasNonZero = false;
				for (int i = 1; i < towers.size(); i++) {
					if (towers.get(i) > 0) {
						hasNonZero = true;
						break;
					}
				}
				if (hasNonZero) { //Game has no winner yet
					prop = getObsProperty("round");
					int newRound = prop.intValue()+1;
					curPlayerId = (curPlayerId+1)%players.size();
					//printMesa(newRound);
					prop.updateValues(newRound,players.get(curPlayerId));
				}

			}
		} else {
			defineObsProperty("violation", getCurrentOpAgentId().getAgentName(), "Bad call play");
		}
	}

	@OPERATION
	void startGame() {
		if (getCurrentOpAgentId().getAgentName().equals("judge")) {
			gameStatus = 1;
			signal("start");
			curPlayerId = 0;
			printMesa(0);
			await_time(400);
			defineObsProperty("round", 0, players.get(0));
		} else {
			defineObsProperty("violation", getCurrentOpAgentId().getAgentName(), "Bad call startGame");
		}
	}

	void printMesa(int round) {
		//if (!printlogs) return;
		System.out.println();
		System.out.println("@ Current round " + round + " Player " + players.get(curPlayerId));
		System.out.println("Mesa: ");
		for (int i = 1; i < towers.size(); i++) {
			System.out.print("tower(" + i + ", " + towers.get(i) + ") ");
		}
		System.out.println();
	}
}

