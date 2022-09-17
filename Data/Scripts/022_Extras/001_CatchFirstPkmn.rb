#===============================================================================
#
#===============================================================================
class CatchFirstPkmn
  attr_accessor :ballcount
  attr_accessor :captures
  attr_accessor :decision
  attr_accessor :steps

  def initialize
    @ballcount  = 0
    @captures   = 0
    @inProgress = false
    @steps      = 0
    @decision   = 0
  end

  def inProgress?
    return @inProgress
  end

  def pbGoToStart
    if $scene.is_a?(Scene_Map)
      pbFadeOutIn {
        $game_temp.player_transferring   = true
        $game_temp.transition_processing = true
        $game_temp.player_new_direction = 2
        pbDismountBike
        $scene.transfer_player
      }
    end
  end

  def pbStart()
    @ballcount  = 10
    @inProgress = true
    @steps      = 999
  end

  def pbEnd
    @ballcount  = 0
    @captures   = 0
    @inProgress = false
    @steps      = 0
    @decision   = 0
    $game_map.need_refresh = true
  end
end

#===============================================================================
#
#===============================================================================

def pbCatchFirstPkmn
  $PokemonGlobal.catchFirstPkmn = CatchFirstPkmn.new if !$PokemonGlobal.catchFirstPkmn
  return $PokemonGlobal.catchFirstPkmn
end

#===============================================================================
#
#===============================================================================

EventHandlers.add(:on_player_step_taken_can_transfer, :CatchFirstPkmn_game_counter,
  proc { |handled|
    # handled is an array: [nil]. If [true], a transfer has happened because of
    # this event, so don't do anything that might cause another one
    next if handled[0]
    next if Settings::CatchFirstPkmn_STEPS == 0 || pbCatchFirstPkmn.decision != 0
    pbCatchFirstPkmn.steps -= 1
    next if pbCatchFirstPkmn.steps > 0
    pbMessage(_INTL("PA: Ding-dong!\1"))
    pbMessage(_INTL("PA: Your CatchFirstPkmn game is over!"))
    pbCatchFirstPkmn.decision = 1
    pbCatchFirstPkmn.pbGoToStart
    handled[0] = true
  }
)

#===============================================================================
#
#===============================================================================
EventHandlers.add(:on_calling_wild_battle, :CatchFirstPkmn_battle,
  proc { |species, level, handled|
    # handled is an array: [nil]. If [true] or [false], the battle has already
    # been overridden (the boolean is its outcome), so don't do anything that
    # would override it again
    next if !handled[0].nil?
    handled[0] = pbCatchFirstPkmnBattle(species, level)
  }
)

def pbCatchFirstPkmnBattle(species, level)
  # Generate a wild Pokémon based on the species and level
  pkmn = pbGenerateWildPokemon(species, level)
  foeParty = [pkmn]
  # Calculate who the trainer is
  playerTrainer = $player
  # Create the battle scene (the visual side of it)
  scene = BattleCreationHelperMethods.create_battle_scene
  # Create the battle class (the mechanics side of it)
  battle = CatchFirstPkmnBattle.new(scene, playerTrainer, foeParty)
  battle.ballCount = pbCatchFirstPkmn.ballcount
  BattleCreationHelperMethods.prepare_battle(battle)
  # Perform the battle itself
  decision = 0
  pbBattleAnimation(pbGetWildBattleBGM(foeParty), 0, foeParty) {
    pbSceneStandby {
      decision = battle.pbStartBattle
    }
  }
  Input.update
  # Update CatchFirstPkmn game data based on result of battle
  pbCatchFirstPkmn.ballcount = battle.ballCount
  if pbCatchFirstPkmn.ballcount <= 0
    if decision != 2   # Last CatchFirstPkmn Ball was used to catch the wild Pokémon
      pbMessage(_INTL("Announcer: You're out of CatchFirstPkmn Balls! Game over!"))
    end
    pbCatchFirstPkmn.decision = 1
    pbCatchFirstPkmn.pbGoToStart
  end
  # Save the result of the battle in Game Variable 1
  #    0 - Undecided or aborted
  #    2 - Player ran out of CatchFirstPkmn Balls
  #    3 - Player or wild Pokémon ran from battle, or player forfeited the match
  #    4 - Wild Pokémon was caught
  if decision == 4
    $stats.CatchFirstPkmn_pokemon_caught += 1
    pbCatchFirstPkmn.captures += 1
    $stats.most_captures_per_CatchFirstPkmn_game = [$stats.most_captures_per_CatchFirstPkmn_game, pbCatchFirstPkmn.captures].max
  end
  pbSet(1, decision)
  # Used by the Poké Radar to update/break the chain
  EventHandlers.trigger(:on_wild_battle_end, species, level, decision)
  # Return the outcome of the battle
  return decision
end

#===============================================================================
#
#===============================================================================
class PokemonPauseMenu
  alias __CatchFirstPkmn_pbShowInfo pbShowInfo unless method_defined?(:__CatchFirstPkmn_pbShowInfo)
end
