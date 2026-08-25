package game

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"

Effect :: union {
    ModifyStatEffect,
    UnlockSkillEffect,
    ApplyImpulseEffect
}
ApplyImpulseEffect :: struct {
    target: ApplyImpulseTarget,
    impulse: f32,
}
ApplyImpulseTarget :: enum {Player}
apply_impulse_target_map: map[string]ApplyImpulseTarget
UnlockSkillEffect :: struct {
    target: UnlockSkillTarget,
    skill: SkillId,
}
UnlockSkillTarget :: enum{Player}
unlock_skill_target_map: map[string]UnlockSkillTarget
ModifyStatEffect :: struct {
    method: ModifyStatMethod,
    entity: ModifyStatEntity,
    target: ModifyStatTarget,
    value: ModifyStatValue,
}
ModifyStatMethod :: enum{Set,Add,Mult}
ModifyStatEntity :: enum{Player}
ModifyStatTarget :: enum{Speed,Size,Velocity}
ModifyStatValue :: union{i32,f32,vec2}

modify_stat_method_map: map[string]ModifyStatMethod
modify_stat_entity_map: map[string]ModifyStatEntity
modify_stat_target_map: map[string]ModifyStatTarget

effector_init :: proc() {
    // method
    modify_stat_method_map["set"]=.Set
    modify_stat_method_map["add"]=.Add
    modify_stat_method_map["multiply"]=.Mult
    // entity
    modify_stat_entity_map["player"]=.Player
    // target
    modify_stat_target_map["speed"]=.Speed
    modify_stat_target_map["size"]=.Size
    modify_stat_target_map["velocity"]=.Velocity


    unlock_skill_target_map["player"]=.Player


    apply_impulse_target_map["player"]=.Player
}

json_object_to_effect :: proc(effect_json: json.Object) -> (Effect, bool) {
    if !("type" in effect_json) do return {}, false
    new_effect: Effect
    switch effect_json["type"].(string) {
    case "unlock_skill":
        if !("target" in effect_json) do return {}, false
        if !("skill" in effect_json) do return {}, false
        skill_id, clone_err := json.clone_string(effect_json["skill"].(string), context.allocator)
        if !(effect_json["target"].(string) in unlock_skill_target_map) do return {}, false
        new_effect = UnlockSkillEffect {target = unlock_skill_target_map[effect_json["target"].(string)], skill = SkillId(skill_id)}
    case "apply_impulse":
        if !("entity" in effect_json) do return {}, false
        if !("value" in effect_json) do return {}, false
        if !(effect_json["entity"].(string) in apply_impulse_target_map) {
            fmt.eprintln("\nundefined entity")
            return {}, false
        }
        new_effect = ApplyImpulseEffect {target = apply_impulse_target_map[effect_json["entity"].(string)], impulse = cast(f32)effect_json["value"].(f64)}
    case "modify_stat":
        if !("method" in effect_json) do return {}, false
        if !("entity" in effect_json) do return {}, false
        if !("target" in effect_json) do return {}, false
        if !("value" in effect_json) do return {}, false
        if !(effect_json["method"].(string) in modify_stat_method_map) ||
            !(effect_json["entity"].(string) in modify_stat_entity_map) ||
            !(effect_json["target"].(string) in modify_stat_target_map)
        {
            fmt.eprintln("\nundefined method/entity/target")
            return {}, false
        }
        new_modify_stat_effect := ModifyStatEffect {
            method = modify_stat_method_map[effect_json["method"].(string)],
            entity = modify_stat_entity_map[effect_json["entity"].(string)],
            target = modify_stat_target_map[effect_json["target"].(string)],
        }
        #partial switch value in effect_json["value"] {
            case i64:
            new_modify_stat_effect.value=i32(value)
            case f64:
            new_modify_stat_effect.value=f32(value)
            case json.Object:
            if "x" in value && "y" in value do new_modify_stat_effect.value = vec2{cast(f32)value["x"].(f64),cast(f32)value["y"].(f64)}
        }
        new_effect = new_modify_stat_effect
    }
    return new_effect, true
}

do_effect :: proc(world: ^World, untyped_effect: Effect) {
    switch effect in untyped_effect {
    case UnlockSkillEffect:
        switch effect.target {
        case .Player:
            for e, &playable in world.playables {
                append(&playable.unlocked_skills, effect.skill)
            }
        }
    case ApplyImpulseEffect:
        switch effect.target {
        case .Player:
            for e, &playable in world.playables {
                world.velocities[e] = playable.direction*effect.impulse
            }
        }
    case ModifyStatEffect:
        target_entities: []Entity
        switch effect.entity {
        case .Player:
            entities, err := slice.map_keys(world.playables)
            if err != nil {
                fmt.eprintfln("\nmap_keys() err: %v", err)
                os.exit(1)
            }
            target_entities=entities
        }
        switch effect.target {
        case .Velocity:
            for e in target_entities {
                switch effect.method {
                case .Set:
                    world.velocities[e] = effect.value.(vec2)
                case .Add:
                    world.velocities[e] += effect.value.(vec2)
                case .Mult:
                    world.velocities[e] *= effect.value.(f32)
                }
            }
        case .Speed:
            for e in target_entities {
                switch effect.method {
                case .Set:
                    world.speeds[e] = effect.value.(f32)
                case .Add:
                    world.speeds[e] += effect.value.(f32)
                case .Mult:
                    world.speeds[e] *= effect.value.(f32)
                }
            }
        case .Size:
            for e in target_entities {
                switch effect.method {
                case .Set:
                    world.sizes[e] = effect.value.(vec2)
                case .Add:
                    world.sizes[e] += effect.value.(vec2)
                case .Mult:
                    world.sizes[e] *= effect.value.(f32)
                }
            }
        }
    }
}
