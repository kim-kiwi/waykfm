package game

import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:path/filepath"

Ability :: struct {
    name: string,
    effects: [dynamic]Effect
}

ability_parser_init :: proc() {
    effector_init()
}

// should delete(free) returned []Ability
parse_ability_files :: proc(app_path: string) -> []Ability {
    abilities_path, alloc_err := filepath.join({app_path,"data","abilities"}, context.allocator)
    if alloc_err != nil {
        fmt.eprintln("Could not make path")
        os.exit(1)
    }
    defer delete(abilities_path)
    fmt.println("We are working on:",app_path)
    fmt.println("Data Dir Path:",abilities_path)
    abilities_dir, open_err := os.open(abilities_path)
    if open_err != nil {
        fmt.eprintfln("Could not open abilities directory: %v", open_err)
        os.exit(1)
    }
    defer os.close(abilities_dir)

    fis: []os.File_Info
    defer os.file_info_slice_delete(fis, context.allocator)
    read_err: os.Error
    fis, read_err = os.read_dir(abilities_dir, 0, context.allocator)
    if read_err != nil {
        fmt.eprintfln("Could not read abilities directory: %v", read_err)
        os.exit(1)
    }

    abilities: [dynamic]Ability
    for fi in fis {
        if fi.type == .Regular {
            fmt.printf("parsing ability at %v...", fi.fullpath)
            ability_data, abil_read_err := os.read_entire_file(fi.fullpath, context.allocator)
            if abil_read_err != nil {
                fmt.eprintfln("Could not open ability file: %v", abil_read_err)
                os.exit(1)
            }
            defer delete(ability_data)

            json_data, json_err := json.parse(ability_data)
            if json_err != nil {
                fmt.printfln("Failed to parse the json file: %v", json_err)
                os.exit(1)
            }
            defer json.destroy_value(json_data)

            new_ability: Ability
            root := json_data.(json.Object)
            if !("name" in root) do continue
            if !("effects" in root) do continue
            clone_err: json.Error
            new_ability.name, clone_err = json.clone_string(root["name"].(string), context.allocator)
            if clone_err != nil {
                fmt.eprintfln("failed to load name: %v", clone_err)
                os.exit(1)
            }
            effect_data_arr := root["effects"].(json.Array)
            for untyped_effect_data in effect_data_arr {
                new_effect, ok := json_object_to_effect(untyped_effect_data.(json.Object))
                if !ok {
                    fmt.eprintln("failed to parse effect")
                    os.exit(1)
                }
                append(&new_ability.effects,new_effect)
            }
            append(&abilities,new_ability)
        }
        fmt.println("done")
    }
    return abilities[:]
}
