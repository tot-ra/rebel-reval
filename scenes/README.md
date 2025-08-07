# Scenes

This directory contains all the game scenes, organized by their location and purpose.

### Scene Flow

These diagrams illustrate the relationships and progression between the major game locations, split by chapter. **Click on a node to view its detailed description.**

#### Chapter 1: The Simmering City
```mermaid
graph TD
    Intro("[Intro]");
    Forge("[The Smith's Forge]");
    Market("[Reval Market]");
    Harbor("[Reval Harbor]");
    GuildHall("[St. Olaf's Guild Hall]");
    Toompea("[Toompea Castle]");
    Cathedral("[Cathedral of St. Mary]");

    Intro --> Forge;
    Forge <--> Market;
    Harbor <--> Market;
    Market <--> GuildHall;
    Market --> Toompea;
    Toompea --> Cathedral;

    click Intro "./intro/intro.md" "Introduction"
    click Forge "./lower_town/the_smiths_forge.md" "The Smith's Forge"
    click Market "./lower_town/market.md" "Reval Market"
    click Harbor "./lower_town/harbor.md" "Reval Harbor"
    click GuildHall "./lower_town/st_olafs_guild_hall.md" "St. Olaf's Guild Hall"
    click Toompea "./upper_town/toompea_castle.md" "Toompea Castle"
    click Cathedral "./upper_town/cathedral_of_saint_mary.md" "Cathedral of St. Mary"
```

#### Chapter 2: The Fire of Rebellion
```mermaid
graph TD
    Reval("Reval City<br>(Lower & Upper Town)");
    RebelCamp("[Rebel Kings' Camp]");
    Parnu("[Pärnu]");
    SwedishOutpost("[Swedish Outpost]");
    SwedishArrival("[Swedish Arrival]");
    PskovBattle("[Pskov Arrival Battle]");

    Reval --> RebelCamp;
    RebelCamp --> Parnu;
    RebelCamp --> SwedishOutpost;
    SwedishOutpost --> SwedishArrival;
    RebelCamp --> PskovBattle;

    click RebelCamp "./events/rebel_kings.md" "Rebel Kings' Camp"
    click Parnu "./events/pernau.md" "Pärnu"
    click SwedishOutpost "./events/swedesh_outpost.md" "Swedish Outpost"
    click SwedishArrival "./events/swedish_arrival.md" "Swedish Arrival"
    click PskovBattle "./events/pskov_arrival_battle.md" "Pskov Arrival Battle"
```

#### Chapter 3 & World Map
```mermaid
graph TD
    WorldMap("[World Map]");
    Saaremaa("[Saaremaa]");
    Paldiski("[Paldiski]");
    
    subgraph "Other World Locations"
        Viljandi("[Viljandi Castle]");
        Padise("[Padise Monastery]");
        Haapsalu("[Haapsalu Castle]");
        Paide("[Paide Castle]");
        Harju("[Harju Village]");
        SacredGrove("[Sacred Grove]");
    end

    WorldMap --> Saaremaa;
    WorldMap --> Paldiski;
    WorldMap --> Viljandi;
    WorldMap --> Padise;
    WorldMap --> Haapsalu;
    WorldMap --> Paide;
    WorldMap --> Harju;
    WorldMap --> SacredGrove;

    click WorldMap "./map/map.md" "World Map"
    click Saaremaa "./events/saaremaa.md" "Saaremaa"
    click Paldiski "./events/paldiski.md" "Paldiski"
    click Viljandi "./world/viljandi_castle.md" "Viljandi Castle"
    click Padise "./world/padise_monastery.md" "Padise Monastery"
    click Haapsalu "./world/haapsalu_castle.md" "Haapsalu Castle"
    click Paide "./world/paide_castle.md" "Paide Castle"
    click Harju "./world/harju_village.md" "Harju Village"
    click SacredGrove "./world/sacred_grove.md" "Sacred Grove"
```

## Scene Index

### System & Menu
- [Main Menu](./menu/main_menu.md)
- [Introduction](./intro/intro.md)
- [World Map](./map/map.md)

### Reval (Tallinn)
#### Lower Town
- [The Smith's Forge](./lower_town/the_smiths_forge.md)
- [Reval Harbor](./lower_town/harbor.md)
- [Reval Market](./lower_town/market.md)
- [St. Olaf's Guild Hall](./lower_town/st_olafs_guild_hall.md)

#### Upper Town (Toompea)
- [Toompea Castle](./upper_town/toompea_castle.md)
- [Cathedral of Saint Mary](./upper_town/cathedral_of_saint_mary.md)

### World Locations
- [Haapsalu Castle](./world/haapsalu_castle.md)
- [Harju Village](./world/harju_village.md)
- [Karja Fortress](./world/karja_fortress.md)
- [Maasilinna Castle](./world/maasilinna_castle.md)
- [Padise Monastery](./world/padise_monastery.md)
- [Paide Castle](./world/paide_castle.md)
- [Pöide Castle](./world/poide_castle.md)
- [Sacred Grove](./world/sacred_grove.md)
- [Viljandi Castle](./world/viljandi_castle.md)

### Event Locations
- [Paldiski](./events/paldiski.md)
- [Pärnu](./events/pernau.md)
- [Pskov Arrival Battle](./events/pskov_arrival_battle.md)
- [Rebel Kings' Camp](./events/rebel_kings.md)
- [Saaremaa](./events/saaremaa.md)
- [Swedish Outpost](./events/swedesh_outpost.md)
- [Swedish Arrival](./events/swedish_arrival.md)
