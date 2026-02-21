# Kenney Assets & Repositories Research

Research for 3D open-world city exploration game in Godot.
All kenney.nl asset packs are **CC0 licensed** (public domain). All GitHub repos use **MIT License** (code) + **CC0** (assets).

---

## PART 1: GitHub Repositories

### 1. Starter-Kit-City-Builder (already using)
- **URL:** https://github.com/KenneyNL/Starter-Kit-City-Builder
- **Stars:** 1,200 | **Godot:** 4.5
- **Contains:** Grid-based city builder template with building/removing structures, smooth camera controls, dynamic MeshLibrary creation, save/load system, 3D city models, sprites, sounds
- **Folders:** models/, structures/, scripts/, sounds/, sprites/, scenes/, fonts/
- **Relevance:** **CORE** - Already the foundation of our project. Provides city building models and placement logic.

### 2. Starter-Kit-3D-Platformer
- **URL:** https://github.com/KenneyNL/Starter-Kit-3D-Platformer
- **Stars:** 1,043 | **Godot:** 4.3
- **Contains:** Character controller (with double jump), camera controls (rotate, zoom), collectable coins, falling platforms, gamepad support, 3D models, sound effects
- **Folders:** models/, meshes/, objects/, scripts/, sounds/, sprites/, scenes/
- **Relevance:** **HIGH** - The character controller with double jump and camera rotation/zoom can be adapted for our player walking around the city. Gamepad support is a bonus. The coin collection system could become a pickup/collectible system.

### 3. Starter-Kit-FPS
- **URL:** https://github.com/KenneyNL/Starter-Kit-FPS
- **Stars:** 844 | **Godot:** 4.3
- **Contains:** First-person character controller, weapon system (switching, cooldown, damage, spread), enemy AI, 3D models, WASD + mouse controls
- **Folders:** models/, objects/, weapons/, scripts/, sounds/, sprites/, scenes/
- **Relevance:** **MEDIUM** - The first-person character controller is useful if we want a first-person exploration mode. Enemy AI patterns could be adapted for NPC behavior. The weapon resource system is a good pattern for any equippable items.

### 4. Starter-Kit-Basic-Scene
- **URL:** https://github.com/KenneyNL/Starter-Kit-Basic-Scene
- **Stars:** 353 | **Godot:** 4.x
- **Contains:** Basic scene and environment setup for pleasing/bright visuals, includes Mini Arena pack models
- **Folders:** scenes/, sample/Mini Arena/
- **Relevance:** **MEDIUM** - Good reference for environment/lighting setup. The bright, pleasing visual style is a good baseline for our city's atmosphere. Can borrow the environment and lighting configuration.

### 5. Godot-SplashScreens
- **URL:** https://github.com/KenneyNL/Godot-SplashScreens
- **Stars:** 1,406
- **Contains:** 70 different 4K splash screens, 18 vector logos, 1 animation for Godot
- **Folders:** Icon/, Logo/, Screen/, Video/
- **License:** CC-BY-4.0 (original Godot logo by Andrea Calabró), CC0 (derivative logos by Kenney)
- **Relevance:** **LOW** - Polish item. Nice for a professional splash screen when launching the game. Can use during development as a placeholder.

---

## PART 2: kenney.nl Asset Packs

### Category A: City/Urban 3D Models (HIGHEST PRIORITY)

#### A1. City Kit (Commercial)
- **URL:** https://kenney.nl/assets/city-kit-commercial
- **Files:** 50 models | **Tags:** city, skyscraper, building
- **Version:** 2.1 (July 2025) - completely remade in 2.0
- **Features:** Color variations
- **Use:** Downtown/commercial district buildings - skyscrapers, office buildings, shops. Core for the city center area.

#### A2. City Kit (Suburban)
- **URL:** https://kenney.nl/assets/city-kit-suburban
- **Files:** 40 models | **Tags:** city, suburban, building
- **Version:** 2.0 (April 2025) - completely remade
- **Features:** Color variations
- **Use:** Residential neighborhoods - houses, small shops, suburban structures. Essential for creating varied city districts.

#### A3. City Kit (Industrial)
- **URL:** https://kenney.nl/assets/city-kit-industrial
- **Files:** 25 models | **Tags:** city, building, factory, warehouse
- **Version:** 1.0 (June 2025)
- **Features:** Color variations
- **Use:** Industrial district - factories, warehouses, industrial structures. Adds variety to city zones.

#### A4. City Kit (Roads)
- **URL:** https://kenney.nl/assets/city-kit-roads
- **Files:** 70 models | **Tags:** road, city, town
- **Version:** 2.0 (March 2025) - optimized, fixed, expanded
- **Features:** Color variations
- **Use:** **ESSENTIAL** - Road network infrastructure: streets, intersections, crosswalks, sidewalks. The backbone of city layout.

#### A5. 3D Road Tiles
- **URL:** https://kenney.nl/assets/3d-road-tiles
- **Files:** 300 models | **Tags:** road, tile
- **Version:** 1.0 (2015)
- **Use:** Alternative/supplementary road pieces. Massive collection of road tiles with various configurations. Older but useful for extra variety.

#### A6. Fantasy Town Kit
- **URL:** https://kenney.nl/assets/fantasy-town-kit
- **Files:** 160 models | **Tags:** medieval, wall, town, building
- **Version:** 2.0 (August 2025) - completely remade
- **Features:** Color variations
- **Use:** Could be used for a historic district or old-town area within the city. Walls, medieval-style buildings add flavor.

---

### Category B: Vehicles & Transport

#### B1. Car Kit
- **URL:** https://kenney.nl/assets/car-kit
- **Files:** 45 models | **Tags:** car, vehicle, transportation
- **Version:** 3.0 (January 2026) - added kart racers + debris
- **Use:** **ESSENTIAL** - Cars, trucks, vans for city streets. Parked cars, traffic, debris for post-accident scenes. Multiple vehicle types for realistic city traffic.

#### B2. Watercraft Kit
- **URL:** https://kenney.nl/assets/watercraft-kit
- **Files:** 45 models | **Tags:** boat, ship, watercraft, vehicle
- **Version:** 2.1 (April 2024) - separated sails/flags
- **Use:** If the city has a harbor/waterfront area - boats, ships, docks. Adds coastal city atmosphere.

---

### Category C: Characters & NPCs

#### C1. Blocky Characters
- **URL:** https://kenney.nl/assets/blocky-characters
- **Files:** 20 models | **Tags:** character
- **Version:** 2.0 (June 2025) - completely remade
- **Features:** Animations included
- **Use:** **HIGH PRIORITY** - Pedestrians/NPCs walking around the city. Player character options. The blocky style matches Kenney's city kit aesthetic.

#### C2. Animated Characters 1
- **URL:** https://kenney.nl/assets/animated-characters-1
- **Files:** 8 models | **Tags:** character, zombie, survivor
- **Version:** 1.0 (2019)
- **Use:** Zombie/survivor characters. Could be used for NPCs or if the city has a survival/zombie mode.

#### C3. Animated Characters 2
- **URL:** https://kenney.nl/assets/animated-characters-2
- **Files:** 8 models | **Tags:** character, skater, cyborg, criminal
- **Version:** 1.0 (2020)
- **Use:** Urban character types - skater, criminal NPCs for city life variety.

#### C4. Animated Characters 3
- **URL:** https://kenney.nl/assets/animated-characters-3
- **Files:** 8 models | **Tags:** character, zombie, survivor
- **Version:** 1.0 (2022)
- **Use:** More character variety for NPCs.

#### C5. Platformer Kit (Characters)
- **URL:** https://kenney.nl/assets/platformer-kit
- **Files:** 150 models | **Tags:** platformer, level
- **Version:** 4.0 (January 2026) - added animated characters
- **Features:** Animations + Color variations
- **Use:** The v4.0 update added animated characters. Some platformer props could double as city playground/park elements.

---

### Category D: Nature & Environment

#### D1. Nature Kit
- **URL:** https://kenney.nl/assets/nature-kit
- **Files:** 330 models | **Tags:** nature, tree, rock, foliage
- **Version:** 1.0 (2020)
- **Use:** **HIGH PRIORITY** - Trees, rocks, bushes, grass for city parks, green spaces, waterfronts. Essential for making the city feel alive with greenery.

#### D2. Holiday Kit
- **URL:** https://kenney.nl/assets/holiday-kit
- **Files:** 100 models | **Tags:** holiday, christmas, tree, cabin
- **Version:** 2.0 (December 2024) - completely remade
- **Features:** Animations included
- **Use:** Seasonal decoration for the city - Christmas trees, lights, snow, cabins. Great for seasonal events or a winter version of the city.

#### D3. Graveyard Kit
- **URL:** https://kenney.nl/assets/graveyard-kit
- **Files:** 90 models | **Tags:** graveyard, halloween, horror, spooky
- **Version:** 5.0 (October 2025) - completely remade
- **Features:** Animations included
- **Use:** Cemetery area in the city. Trees and fences from this kit could also be reused as park elements. Good for a spooky district.

#### D4. Minigolf Kit
- **URL:** https://kenney.nl/assets/minigolf-kit
- **Files:** 125 models | **Tags:** golf, course, level
- **Version:** 3.1 (March 2025)
- **Features:** Color variations
- **Use:** Mini-golf course as a city recreational area. Props like fences, windmills, decorations could be repurposed as city park elements.

---

### Category E: Interior & Props

#### E1. Furniture Kit
- **URL:** https://kenney.nl/assets/furniture-kit
- **Files:** 140 models | **Tags:** furniture, interior, table, chair, bed
- **Version:** 1.0 (2018)
- **Use:** Interior decoration for explorable buildings - offices, apartments, shops, restaurants. Tables, chairs, beds, shelves etc.

#### E2. Food Kit
- **URL:** https://kenney.nl/assets/food-kit
- **Files:** 200 models | **Tags:** food, kitchen, eat
- **Version:** 2.0 (June 2024) - completely remade
- **Use:** Restaurant/cafe interiors, street food stalls, market scenes. Modular food items (hamburgers, pizza can be taken apart).

---

### Category F: UI Elements

#### F1. UI Pack
- **URL:** https://kenney.nl/assets/ui-pack
- **Files:** 430 sprites | **Tags:** button, panel, slider, interface
- **Version:** 2.0 (June 2024) - completely remade
- **Use:** **HIGH PRIORITY** - Complete UI framework: buttons, panels, sliders, progress bars, checkboxes. Perfect for menus, HUD, inventory, settings screens.

#### F2. UI Pack - Adventure
- **URL:** https://kenney.nl/assets/ui-pack-adventure
- **Files:** 130 sprites | **Tags:** button, panel, slider, interface
- **Version:** 1.0 (August 2024)
- **Use:** Adventure-themed UI elements. Could work well for the exploration game feel - inventory panels, quest logs, map overlays.

#### F3. Input Prompts
- **URL:** https://kenney.nl/assets/input-prompts
- **Files:** 1,280 sprites | **Tags:** input, prompt, button, gamepad, control
- **Version:** 1.4a (November 2025)
- **Use:** **HIGH PRIORITY** - Controller/keyboard button prompts for tutorials and control hints. Covers keyboard, mouse, PlayStation 1-5, Xbox, Nintendo Switch/Switch 2, Steam Deck, Gamecube, touch gestures. Includes spritesheets and fonts.

#### F4. Cursor Pack
- **URL:** https://kenney.nl/assets/cursor-pack
- **Files:** 180 sprites | **Tags:** cursor, icon, interface
- **Version:** 1.1 (June 2024)
- **Use:** Custom mouse cursors for the game - pointer, interact, grab, etc.

#### F5. Emotes Pack
- **URL:** https://kenney.nl/assets/emotes-pack
- **Files:** 480 sprites | **Tags:** emote, icon, balloon
- **Version:** 1.0 (2018)
- **Use:** Speech bubble emotes for NPCs - question marks, exclamation marks, hearts, anger, etc. Great for visual NPC communication without text.

---

### Category G: Audio & Sound Effects

#### G1. Interface Sounds
- **URL:** https://kenney.nl/assets/interface-sounds
- **Files:** 100 sounds | **Tags:** interface, click, button
- **Version:** 1.0 (2020)
- **Use:** **HIGH PRIORITY** - Menu clicks, button hovers, notifications, UI feedback sounds.

#### G2. UI Audio
- **URL:** https://kenney.nl/assets/ui-audio
- **Files:** 50 sounds | **Tags:** button, switch, click
- **Version:** 1.0 (2012)
- **Use:** Additional UI sounds - button clicks, switches, toggles.

#### G3. Impact Sounds
- **URL:** https://kenney.nl/assets/impact-sounds
- **Files:** 130 sounds | **Tags:** impact, foley
- **Version:** 1.0 (2019)
- **Use:** Collision sounds - player bumping into objects, car crashes, door slams, physical interactions in the city.

#### G4. RPG Audio
- **URL:** https://kenney.nl/assets/rpg-audio
- **Files:** 50 sounds | **Tags:** foley, rpg, footstep, weapon
- **Version:** 1.0 (2014)
- **Use:** **Footstep sounds** are the key item here - essential for player walking in the city. Also general foley sounds.

#### G5. Music Jingles
- **URL:** https://kenney.nl/assets/music-jingles
- **Files:** 85 tracks | **Tags:** music, jingle
- **Version:** 1.0 (2014)
- **Use:** Short music stings for achievements, discoveries, level transitions, quest completion. Good for exploration milestones.

#### G6. Casino Audio
- **URL:** https://kenney.nl/assets/casino-audio
- **Use:** Niche - only relevant if the city has a casino/entertainment district.

#### G7. Digital Audio
- **URL:** https://kenney.nl/assets/digital-audio
- **Files:** 60 sounds | **Tags:** space, laser
- **Use:** LOW relevance - Sci-fi/space sounds. Could be repurposed for electronic city sounds (ATMs, vending machines).

#### G8. Sci-fi Sounds
- **URL:** https://kenney.nl/assets/sci-fi-sounds
- **Use:** LOW relevance unless the city has futuristic elements.

---

### Category H: Textures

#### H1. Road Textures
- **URL:** https://kenney.nl/assets/road-textures
- **Files:** 90 textures | **Tile size:** 64x64 | **Tags:** texture, road
- **Version:** 1.0 (2019)
- **Use:** Road surface textures - asphalt, markings, crosswalks. Can be applied to custom road geometry.

#### H2. Development Essentials
- **URL:** https://kenney.nl/assets/development-essentials
- **Files:** 15 textures | **Tags:** essential, prototype
- **Version:** 1.1 (January 2026)
- **Use:** Prototyping textures (grids, checkerboards) useful during development for testing scale and layout.

#### H3. Retro Textures 1
- **URL:** https://kenney.nl/assets/retro-textures-1
- **Files:** 115 textures | **Tags:** retro, texture
- **Version:** 1.0 (January 2026)
- **Use:** Stylized retro textures. Could be used if going for a retro aesthetic on certain buildings.

---

## PART 3: Priority Integration Plan

### Tier 1 - ESSENTIAL (integrate first)
| Asset | Why |
|-------|-----|
| City Kit (Roads) | Road network - city backbone |
| City Kit (Commercial) | Downtown buildings |
| City Kit (Suburban) | Residential areas |
| Car Kit | Street vehicles |
| Nature Kit | Parks, trees, greenery |
| Blocky Characters | Player + NPCs |
| UI Pack | Game interface |
| Input Prompts | Control hints |

### Tier 2 - HIGH VALUE (integrate next)
| Asset | Why |
|-------|-----|
| City Kit (Industrial) | Industrial district variety |
| Furniture Kit | Building interiors |
| Interface Sounds | UI audio feedback |
| RPG Audio | Footsteps |
| Impact Sounds | Physical interactions |
| Emotes Pack | NPC communication |
| Starter-Kit-3D-Platformer | Character controller code |

### Tier 3 - NICE TO HAVE (polish phase)
| Asset | Why |
|-------|-----|
| Food Kit | Restaurant/market detail |
| Watercraft Kit | Harbor/waterfront |
| Fantasy Town Kit | Historic district |
| Holiday Kit | Seasonal events |
| Cursor Pack | Custom cursors |
| Music Jingles | Achievement stings |
| UI Pack - Adventure | Themed UI variant |
| Godot-SplashScreens | Splash screen |
| Road Textures | Custom road surfaces |
| Animated Characters 1-3 | More NPC variety |
| Starter-Kit-FPS | First-person mode reference |
| Starter-Kit-Basic-Scene | Lighting/env reference |

### Tier 4 - CONDITIONAL
| Asset | When |
|-------|------|
| Graveyard Kit | If city has cemetery |
| Minigolf Kit | If city has recreation areas |
| Casino Audio | If city has entertainment district |
| Development Essentials | During prototyping only |
| Retro Textures | If retro aesthetic desired |

---

## PART 4: Download Links (Direct)

All free, no registration required:

```
# Tier 1 Essential
https://kenney.nl/assets/city-kit-roads
https://kenney.nl/assets/city-kit-commercial
https://kenney.nl/assets/city-kit-suburban
https://kenney.nl/assets/car-kit
https://kenney.nl/assets/nature-kit
https://kenney.nl/assets/blocky-characters
https://kenney.nl/assets/ui-pack
https://kenney.nl/assets/input-prompts

# Tier 2 High Value
https://kenney.nl/assets/city-kit-industrial
https://kenney.nl/assets/furniture-kit
https://kenney.nl/assets/interface-sounds
https://kenney.nl/assets/rpg-audio
https://kenney.nl/assets/impact-sounds
https://kenney.nl/assets/emotes-pack

# GitHub Repos
https://github.com/KenneyNL/Starter-Kit-City-Builder
https://github.com/KenneyNL/Starter-Kit-3D-Platformer
https://github.com/KenneyNL/Starter-Kit-FPS
https://github.com/KenneyNL/Starter-Kit-Basic-Scene
https://github.com/KenneyNL/Godot-SplashScreens
```

## PART 5: Total Asset Count Summary

| Category | Packs | Total Files |
|----------|-------|-------------|
| City/Urban 3D | 6 packs | ~635 models |
| Vehicles | 2 packs | ~90 models |
| Characters | 5 packs | ~194 models |
| Nature/Environment | 4 packs | ~645 models |
| Interior/Props | 2 packs | ~340 models |
| UI Elements | 5 packs | ~2,500 sprites |
| Audio | 8 packs | ~525 sounds |
| Textures | 3 packs | ~220 textures |
| **TOTAL** | **35 packs** | **~5,149 assets** |
