package game

import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:path/filepath"
import "core:strings"

SkillId :: distinct string
Skill :: struct {
    name: string,
    symbol: string,
    type: SkillType,
    effects: [dynamic]Effect,
}
SkillType :: enum {Active}

skill_type_map: map[string]SkillType

skill_parser_init :: proc() {
    skill_type_map["active"]=.Active
}

parse_skill_files :: proc(app_path: string) -> map[SkillId]Skill {
    skills_path, alloc_err := filepath.join({app_path,"data","skills"}, context.allocator)
    if alloc_err != nil {
        fmt.eprintln("Could not make path")
        os.exit(1)
    }
    defer delete(skills_path)
    skills_dir, open_err := os.open(skills_path)
    if open_err != nil {
        fmt.eprintfln("Could not open skills directory: %v", open_err)
        os.exit(1)
    }
    defer os.close(skills_dir)

    fis: []os.File_Info
    defer os.file_info_slice_delete(fis, context.allocator)
    read_err: os.Error
    fis, read_err = os.read_dir(skills_dir, 0, context.allocator)
    if read_err != nil {
        fmt.eprintfln("Could not read skills directory: %v", read_err)
        os.exit(1)
    }

    skills: map[SkillId]Skill
    for fi in fis {
        if fi.type == .Regular {
            fmt.printf("parsing skill at %v...", fi.fullpath)
            skill_data, skill_read_err := os.read_entire_file(fi.fullpath, context.allocator)
            if skill_read_err != nil {
                fmt.eprintfln("Could not open skill file: %v", skill_read_err)
                os.exit(1)
            }
            defer delete(skill_data)

            json_data, json_err := json.parse(skill_data)
            if json_err != nil {
                fmt.printfln("Failed to parse the json file: %v", json_err)
                os.exit(1)
            }
            defer json.destroy_value(json_data)

            new_skill: Skill
            root := json_data.(json.Object)
            if !("id" in root) do continue
            if !("symbol" in root) do continue
            if !("name" in root) do continue
            if !("type" in root) do continue
            if !("effects" in root) do continue
            new_skill.name = strings.clone(root["name"].(string), context.allocator)
            new_skill.symbol = strings.clone(root["symbol"].(string), context.allocator)
            skill_exists: bool
            new_skill.type, skill_exists = skill_type_map[root["type"].(string)]
            if !skill_exists {
                fmt.eprintln("undefined skill")
                os.exit(1)
            }
            effect_data_arr := root["effects"].(json.Array)
            for untyped_effect_data in effect_data_arr {
                new_effect, ok := json_object_to_effect(untyped_effect_data.(json.Object))
                if !ok {
                    fmt.eprintln("failed to parse effect")
                    os.exit(1)
                }
                append(&new_skill.effects,new_effect)
            }
            skill_id, clone_err := json.clone_string(root["id"].(string), context.allocator)
            if clone_err != nil {
                fmt.eprintfln("failed to load skill id: %v", clone_err)
                os.exit(1)
            }
            skills[SkillId(skill_id)]=new_skill
        }
        fmt.println("done")
    }
    return skills
}
