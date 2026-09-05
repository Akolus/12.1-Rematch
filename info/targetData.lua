local _,rematch = ...
local L = rematch.localization
rematch.targetData = {}

--[[
    This file contains the raw data for all notable targets: tamers, pet dungeons, world quests, etc.

    The format of each record in rematch.targetData.notableTargets:
        headerID: mapID if a number, or named string otherwise; the target list headers
        npcID: the npcID of the target
        mapID: the mapID the target is in (at the most "zoomed-in" level)
        expansionID: the expansion the battle is associated with (pre-MoP) or added (MoP and above)
        questID: (optional) the questID of the quest the npc is associated with (can be nil)
        pet1: the link-formatted string ("battlepet:speciesID:level:rarity:health:power:speed") of the first pet
        pet2: (optional) the link-formatted string of the second pet
        pet3: (optional) the link-formatted string of the third pet

    For new targets, travel to the target, target it, and then enter a battle. Once opponent pets load:
        /rematch targetdata
    This will generate a formatted string to paste into this file. It will not fill in expansionID or questID,
    those need to be manually added. Also if the target is in a dungeon/subzone, the headerID may need adjusted
    (or the mapID); most of the time they're the same but they can be different.
]]

-- the order of targets in this table is the order they will be listed. generally it should be most recent
-- content first, though one-off additions like Anthea added to Pandaria in the Shadowlands expansions is
-- added to the top of the Pandaria targets.
rematch.targetData.notableTargets = {
    -- Isle of Dorn (2248)
    {2248,223446,2248,10,nil,"battlepet:4551:25:4:1587:297:297","battlepet:4550:25:3:1481:276:276","battlepet:4549:25:3:1481:374:276"}, -- Isle of Dorn, Collector Dyna
    {2248,223407,2248,10,nil,"battlepet:4561:25:5:2426:300:338"}, -- Isle of Dorn, Awakened Custodian
    -- The Ringing Deeps (2214)
    {2214,223444,2214,10,nil,"battlepet:4564:25:4:1587:297:297","battlepet:4553:25:4:1587:297:297","battlepet:4554:25:3:1481:276:276"}, -- The Ringing Deeps, Friendhaver Grem
    {2214,222535,2214,10,nil,"battlepet:4488:25:5:2020:342:244"}, -- The Ringing Deeps, Haywire Servobot
    -- Hallowfall
    {2215,223442,2215,10,nil,"battlepet:4559:25:3:1481:276:276","battlepet:4555:25:4:1587:297:297","battlepet:4552:25:3:1481:276:276"}, -- Hallowfall, Kyrie
    {2215,223409,2215,10,nil,"battlepet:4562:25:5:2504:285:319"}, -- Hallowfall, Guttergunk
    -- AkAzj-Kahet
    {2255,223406,2255,10,nil,"battlepet:4560:25:5:2036:330:338"}, -- Azj-Kahet, Zaedu
    -- Zirik is in City of Threads dungeon?
    -- The Waking Shores (2022)
    {2022,196264,2022,9,66551,"battlepet:3387:25:2:1225:285:255","battlepet:3386:25:3:1684:317:195","battlepet:3388:25:4:2112:332:385"}, -- The Waking Shores, Haniko
    {2022,189376,2022,9,66588,"battlepet:3268:25:5:4183:315:300"}, -- The Waking Shores, Swog
    {2022,201802,2022,9,74840,"battlepet:3452:25:4:2095:346:306","battlepet:3451:25:4:1675:420:280","battlepet:3450:25:4:1850:367:332"}, -- The Waking Shores, Excavator Morgrum Emberflint
    {2022,201849,2022,9,74841,"battlepet:3453:25:5:1645:255:300"}, -- The Waking Shores, Adinakon
    -- Ohn'ahran Plains (2023)
    {2023,197102,2023,9,71140,"battlepet:3392:25:4:1587:297:227","battlepet:3391:25:4:2112:297:297"}, -- Ohn'ahran Plains, Bakhushek
    {2023,197447,2023,9,71206,"battlepet:3402:25:5:1801:285:338"}, -- Ohn'ahran Plains, Stormamu
    {2023,201878,2023,9,74837,"battlepet:3457:25:4:1412:364:346","battlepet:3456:25:4:1675:367:315","battlepet:3455:25:4:1500:381:346"}, -- Ohn'ahran Plains, Vikshi Thunderpaw
    {2023,201858,2023,9,74838,"battlepet:3454:25:5:1958:297:367"}, -- Ohn'ahran Plains, Lyver
    -- The Azure Span (2024)
    {2024,197417,2024,9,71202,"battlepet:3401:25:5:2192:285:263"}, -- The Azure Span, Arcantus
    {2024,196069,2024,9,71145,"battlepet:3393:25:4:1631:297:262","battlepet:3394:25:4:1412:297:262","battlepet:3395:25:4:1062:329:311"}, -- The Azure Span, Patchu
    {2024,196206,2024,9,70732,3377}, -- Gwosh
    {2024,201899,2024,9,74836,"battlepet:3460:25:4:1832:297:311","battlepet:3459:25:4:1832:297:311","battlepet:3458:25:4:1832:297:311"}, -- Izal Whitemoon
    {2024,202440,2024,9,74835,"battlepet:3465:25:5:1958:330:333"}, -- Enok the Stinky
    -- Thaldraszus (2025)
    {2025,197336,2025,9,71166,"battlepet:3396:25:5:2036:315:300"}, -- Thaldraszus, Enyobon
    {2025,197350,2025,9,71180,"battlepet:3397:25:0:1169:175:263","battlepet:3398:25:2:1375:278:278","battlepet:3400:25:3:1644:309:276"}, -- Thaldraszus, Setimothes
    {2025,202458,2025,9,74792,"battlepet:3474:25:5:1881:375:281","battlepet:3473:25:5:1600:390:371","battlepet:3472:25:5:1413:375:263"}, -- Stargazer Zenoth
    {2025,202452,2025,9,74794,"battlepet:3466:25:5:3051:285:300"}, -- Malfunctioning Matrix
    -- Forbidden Reach (2151)
    {2151,200677,2151,9,73146,"battlepet:3444:25:4:2489:224:280"}, -- Storm-Touched Swoglet
    {2151,200684,2151,9,73146,"battlepet:3429:25:5:3207:315:394"}, -- Vortex (Legendary)
    {2151,200682,2151,9,73146,"battlepet:3433:25:4:2270:259:324"}, -- Vortex (Epic)
    {2151,200685,2151,9,73146,"battlepet:3437:25:3:1843:234:292"}, -- Vortex (Rare)
    {2151,200679,2151,9,73148,"battlepet:3442:25:4:2416:266:245"}, -- Storm-Touched Skitterer
    {2151,200688,2151,9,73148,"battlepet:3431:25:5:3207:315:394"}, -- Wildfire (Legendary)
    {2151,200686,2151,9,73148,"battlepet:3435:25:4:2489:273:341"}, -- Wildfire (Epic)
    {2151,200689,2151,9,73148,"battlepet:3439:25:3:1775:240:301"}, -- Wildfire (Rare)
    {2151,200678,2151,9,73147,"battlepet:3443:25:4:2270:224:332"}, -- Storm-Touched Slyvern
    {2151,200692,2151,9,73147,"battlepet:3430:25:5:3988:255:281"}, -- Tremblor (Legendary)
    {2151,200690,2151,9,73147,"battlepet:3434:25:4:3108:231:245"}, -- Tremblor (Epic)
    {2151,200693,2151,9,73147,"battlepet:3438:25:3:2317:208:211"}, -- Tremblor (Rare)
    {2151,200680,2151,9,73149,"battlepet:3441:25:4:2051:266:332"}, -- Storm-Touched Ohuna
    {2151,200696,2151,9,73149,"battlepet:3432:25:5:3793:278:300"}, -- Flow (Legendary)
    {2151,200694,2151,9,73149,"battlepet:3436:25:4:2944:241:271"}, -- Flow (Epic)
    {2151,200697,2151,9,73149,"battlepet:3440:25:3:2131:218:244"}, -- Flow (Rare)
    -- Zaralek Caverns (2133)
    {2133,204926,2133,9,75834,"battlepet:3570:25:4:1587:402:297","battlepet:3569:25:4:1587:402:297","battlepet:3568:25:4:1675:350:350"}, -- Delver Mardei
    {2133,201004,2133,9,75680,"battlepet:3560:25:3:1481:341:308","battlepet:3559:25:3:1481:374:276","battlepet:3558:25:4:1762:332:367"}, -- Explorer Bezzert
    {2133,204792,2133,9,75750,"battlepet:3565:25:3:1725:374:308","battlepet:3566:25:3:1969:325:276","battlepet:3567:25:4:1762:350:332"}, -- Shinmura
    {2133,204934,2133,9,75835,"battlepet:3572:25:3:1887:309:276","battlepet:3571:25:5:1694:394:319","battlepet:3573:25:4:2025:332:297"}, -- Trainer Orlogg

    -- Ardenweald (1565)
    {1565,175778,1565,8,nil,"battlepet:3070:25:5:2036:375:319"}, -- Ardenweald, Briarpaw
    {1565,175779,1565,8,nil,"battlepet:3071:25:5:2114:360:300"}, -- Ardenweald, Chittermaw
    {1565,173377,1565,8,61948,"battlepet:3003:25:3:1952:333:330","battlepet:3004:25:3:1671:361:332","battlepet:3005:25:3:2113:403:403"}, -- Ardenweald, Faryl (Star Tail, Needlenose, Brite)
    {1565,173372,1565,8,61946,"battlepet:3000:25:3:1684:387:411","battlepet:3001:25:3:2196:330:354","battlepet:3002:25:3:1928:362:317"}, -- Ardenweald, Glitterdust (Slugger, Runehoof, Duster)
    {1565,175780,1565,8,nil,"battlepet:3072:25:5:2426:345:319"}, -- Ardenweald, Mistwing
    {1565,173376,1565,8,61947,"battlepet:2998:25:3:2791:273:314"}, -- Ardenweald, Nightfang
    {1565,173381,1565,8,61949,"battlepet:2999:25:3:2858:283:341"}, -- Ardenweald, Rascal
    -- Bastion (1533)
    {1533,175777,1533,8,nil,"battlepet:3068:25:5:2192:330:225"}, -- Bastion, Crystalsnap
    {1533,175783,1533,8,nil,"battlepet:3075:25:5:2348:360:338"}, -- Bastion, Digallo
    {1533,173133,1533,8,61783,"battlepet:2968:25:3:2303:202:138"}, -- Bastion, Jawbone
    {1533,175785,1533,8,nil,"battlepet:3077:25:5:2270:420:356"}, -- Bastion, Kostos
    {1533,173131,1533,8,61784,"battlepet:2972:25:3:1684:289:249","battlepet:2973:25:3:1197:406:333","battlepet:2974:25:3:1847:333:276"}, -- Bastion, Stratios (Shelby, Tinyhoof, Glitterwing)
    {1533,173129,1533,8,61791,"battlepet:2969:25:3:1766:223:447","battlepet:2970:25:3:1766:349:285","battlepet:2971:25:3:2253:284:219"}, -- Bastion, Thenia (Sunset Glimmerfly, Plains Peachick, Golden Grazer)
    {1533,173130,1533,8,61787,"battlepet:2975:25:3:2172:333:236","battlepet:2976:25:3:1400:289:370","battlepet:2977:25:3:2237:357:249"}, -- Bastion, Zolla (Battery, Slasher, Pounder)
    -- Maldraxxus (1536)
    {1536,173257,1536,8,61866,"battlepet:2980:25:3:1989:292:325","battlepet:2981:25:3:2416:528:219","battlepet:2982:25:3:1969:422:455"}, -- Maldraxxus, Caregiver Maximillian (Bloog, Bone Crusher, Chipper)
    {1536,173267,1536,8,61868,"battlepet:2986:25:3:2034:357:249","battlepet:2987:25:3:1806:357:439","battlepet:2988:25:3:1583:341:309"}, -- Maldraxxus, Dundley Stickyfingers (Whirly, Stinkdust, Trailblazer)
    {1536,175784,1536,8,nil,"battlepet:3076:25:5:2504:435:263"}, -- Maldraxxus, Gelatinous
    {1536,175786,1536,8,nil,"battlepet:3078:25:5:2582:405:281"}, -- Maldraxxus, Glurp
    {1536,173274,1536,8,61870,"battlepet:2978:25:3:3488:338:249"}, -- Maldraxxus, Gorgemouth
    {1536,173263,1536,8,61867,"battlepet:2983:25:3:1729:317:318","battlepet:2984:25:3:2355:382:289","battlepet:2985:25:3:1684:512:219"}, -- Maldraxxus, Rotgut (Leftovers, Leftovers, Leftovers)
    -- Revendreth (1525)
    {1525,173331,1525,8,61886,"battlepet:2996:25:3:3025:325:219"}, -- Revendreth, Addius the Tormentor (Wretch)
    {1525,173324,1525,8,61885,"battlepet:2992:25:3:1887:366:317","battlepet:2993:25:3:2356:280:333","battlepet:2994:25:3:2741:317:219"}, -- Revendreth, Eyegor (Boneclaw, Spindler, Rocko)
    {1525,173303,1525,8,61879,"battlepet:2979:25:3:2879:361:366"}, -- Revendreth, Scorch
    {1525,175781,1525,8,nil,"battlepet:3073:25:5:2192:375:309"}, -- Revendreth, Sewer Creeper
    {1525,173315,1525,8,61883,"battlepet:2989:25:3:1928:362:260","battlepet:2990:25:3:1766:333:333","battlepet:2991:25:3:1400:484:219"}, -- Revendreth, Sylla (Ash, Fang, Swarm)
    {1525,175782,1525,8,nil,"battlepet:3074:25:5:2036:405:328"}, -- Revendreth, The Countess
    -- Blackrock Depths (1578)
    {1578,160209,1578,7,58458,"battlepet:2801:25:4:1391:350:280","battlepet:2800:25:4:1566:324:284","battlepet:2799:25:4:1500:324:280"}, -- Blackrock Depths, Horu Cloudwatcher (Bomber, Beta, Alpha)
    {1578,161650,1578,7,58458,"battlepet:2816:25:4:1978:267:305"}, -- Blackrock Depths, Liz
    {1578,161651,1578,7,58458,"battlepet:2817:25:4:1978:249:355"}, -- Blackrock Depths, Ralf
    {1578,161649,1578,7,58458,"battlepet:2815:25:4:2270:273:324"}, -- Blackrock Depths, Rampage
    {1578,160207,1578,7,58458,"battlepet:2802:25:4:1850:311:333","battlepet:2803:25:4:1806:289:311"}, -- Blackrock Depths, Therin Skysong (Logic, Math)
    {1578,161662,1578,7,58458,"battlepet:2822:25:4:2197:287:324"}, -- Blackrock Depths, Char
    {1578,161663,1578,7,58458,"battlepet:2823:25:4:1978:320:305"}, -- Blackrock Depths, Tempton
    {1578,161661,1578,7,58458,"battlepet:2821:25:4:2270:255:324"}, -- Blackrock Depths, Wilbur
    {1578,161657,1578,7,58458,"battlepet:2819:25:4:1978:291:355"}, -- Blackrock Depths, Ninn Jah
    {1578,161658,1578,7,58458,"battlepet:2820:25:4:2110:335:305"}, -- Blackrock Depths, Shred
    {1578,161656,1578,7,58458,"battlepet:2818:25:4:1978:224:394"}, -- Blackrock Depths, Splint
    {1578,160206,1578,7,58458,"battlepet:2804:25:4:1500:236:376","battlepet:2805:25:4:1916:219:254","battlepet:2806:25:4:1767:250:302"}, -- Blackrock Depths, Alran Heartshade (Frill, Ruddy, Wanderer)
    {1578,160208,1578,7,58458,"battlepet:2807:25:4:1723:268:245","battlepet:2808:25:4:1631:350:236","battlepet:2809:25:4:1723:297:192"}, -- Blackrock Depths, Zuna Skullcrush (Crushface, Fozling, Tremors)
    {1578,160210,1578,7,58458,"battlepet:2810:25:4:1526:342:315","battlepet:2811:25:4:2200:267:306","battlepet:2812:25:4:1828:350:293"}, -- Blackrock Depths, Tasha Riley (Presto, Fury, Glitzy)
    {1578,160205,1578,7,58458,"battlepet:2814:25:5:13319:403:206"}, -- Blackrock Depths, Pixy Wizzle (Gigacharged Mayhem Maker)
    -- Stratholme (1505)
    {1505,150923,1505,7,56492,"battlepet:2609:25:3:1268:143:260","battlepet:2611:25:3:1403:305:203","battlepet:2601:25:3:1200:175:260"}, -- Stratholme, Belchling
    {1505,150922,1505,7,56492,"battlepet:2608:25:4:2634:259:192"}, -- Stratholme, Sludge Belcher
    {1505,150914,1505,7,56492,"battlepet:2600:25:3:1288:244:334","battlepet:2606:25:3:1288:264:301","battlepet:2601:25:3:1200:175:260"}, -- Stratholme, Wandering Phantasm
    {1505,150911,1505,7,56492,"battlepet:2597:25:3:1335:244:370","battlepet:2611:25:3:1403:305:203","battlepet:2598:25:3:1268:240:301"}, -- Stratholme, Crypt Fiend
    {1505,150925,1505,7,56492,"battlepet:2612:25:4:1869:224:319"}, -- Stratholme, Liz the Tormentor
    {1505,155145,1505,7,56492,"battlepet:2595:25:0:1041:226:188","battlepet:2594:25:0:1006:250:219","battlepet:2593:25:0:1350:156:200"}, -- Stratholme, Plagued Critters (Diseased Rat, Plague Rat, Plague Roach)
    {1505,155267,1505,7,56492,"battlepet:2751:25:3:1322:251:297","battlepet:2611:25:3:1403:305:203","battlepet:2598:25:3:1268:240:301"}, -- Stratholme, Risen Guard
    {1505,150929,1505,7,56492,"battlepet:2613:25:4:2161:301:302"}, -- Stratholme, Nefarious Terry
    {1505,150918,1505,7,56492,"battlepet:2603:25:3:1403:253:406"}, -- Stratholme, Tommy the Cruel
    {1505,150917,1505,7,56492,"battlepet:2602:25:3:1505:325:260"}, -- Stratholme, Huncher
    {1505,150858,1505,7,56492,"battlepet:2592:25:4:1322:273:254"}, -- Stratholme, Blackmane
    {1505,155414,1505,7,56492,"battlepet:2768:25:4:1102:315:245","battlepet:2769:25:4:1176:250:236","battlepet:2770:25:4:1789:259:241"}, -- Stratholme, Ezra Grimm (Smokey, Pyro, Infectus)
    {1505,155413,1505,7,56492,"battlepet:2774:25:4:1500:311:276","battlepet:2771:25:4:1570:307:311","battlepet:2772:25:4:2226:215:255"}, -- Stratholme, Postmaster Malown (Lefty, Plagued Mailemental, Soul Collector)
    -- Gnomeregan (842)
    {842,146001,840,7,54186,"battlepet:2501:25:4:2634:252:280"}, -- Gnomeregan, Prototype Annoy-O-Tron
    {842,146182,841,7,54186,"battlepet:2503:25:3:1406:231:289","battlepet:2486:25:3:1775:195:260","battlepet:2486:25:3:1775:195:260"}, -- Gnomeregan, Living Sludge
    {842,146183,841,7,54186,"battlepet:2502:25:3:1403:292:260","battlepet:2500:25:3:1166:208:406","battlepet:2496:25:3:1322:264:273"}, -- Gnomeregan, Living Napalm
    {842,146181,841,7,54186,"battlepet:2504:25:3:1945:208:227","battlepet:2485:25:3:1335:241:301","battlepet:2496:25:3:1322:264:273"}, -- Gnomeregan, Living Permafrost
    {842,146932,841,7,54186,"battlepet:2497:25:4:1062:350:324","battlepet:2498:25:4:1150:297:254","battlepet:2499:25:4:1150:297:262"}, -- Gnomeregan, Door Control Console (Ultra Safe Napalm Carrier, Freeze Ray Robot Prototype, Sludge Disposal Unit)
    {842,145971,842,7,54186,"battlepet:2486:25:3:1775:195:260","battlepet:2496:25:3:1322:264:273","battlepet:2486:25:3:1775:195:260"}, -- Gnomeregan, Cockroach
    {842,145968,842,7,54186,"battlepet:2485:25:3:1335:241:301","battlepet:2490:25:3:2046:240:260","battlepet:2500:25:3:1166:208:406"}, -- Gnomeregan, Leper Rat
    {842,146005,842,7,54186,"battlepet:2495:25:4:3254:312:311"}, -- Gnomeregan, Bloated Leper Rat
    {842,146004,842,7,54186,"battlepet:2494:25:3:1457:218:346","battlepet:2486:25:3:1775:195:260","battlepet:2485:25:3:1335:241:301"}, -- Gnomeregan, Gnomeregan Guard Mechanostrider
    {842,146003,842,7,54186,"battlepet:2493:25:3:1525:218:314","battlepet:2490:25:3:2046:240:260","battlepet:2486:25:3:1775:195:260"}, -- Gnomeregan, Gnomeregan Guard Tiger
    {842,146002,842,7,54186,"battlepet:2492:25:3:1166:238:330","battlepet:2487:25:3:1220:228:330","battlepet:2496:25:3:1322:264:273"}, -- Gnomeregan, Gnomeregan Guard Wolf
    {842,145988,842,7,54186,"battlepet:2488:25:4:1308:200:294"}, -- Gnomeregan, Pulverizer Bot Mk 6001
    -- Mechagon Island (1462)
    {1462,154926,1462,7,56397,"battlepet:2739:25:5:1879:420:300"}, -- Mechagon Island, CK-9 Micro-Oppression Unit
    {1462,154925,1462,7,56396,"battlepet:2738:25:5:1879:420:309"}, -- Mechagon Island, Creakclank
    {1462,154922,1462,7,56393,"battlepet:2735:25:5:1723:405:319"}, -- Mechagon Island, Gnomefeaster
    {1462,154924,1462,7,56395,"battlepet:2737:25:5:1879:405:291"}, -- Mechagon Island, Goldenbot XD
    {1462,154923,1462,7,56394,"battlepet:2736:25:5:1840:420:244"}, -- Mechagon Island, Sputtertube
    {1462,154928,1462,7,56399,"battlepet:2741:25:5:1723:435:253"}, -- Mechagon Island, Unit 6
    {1462,154929,1462,7,56400,"battlepet:2742:25:5:1723:435:225"}, -- Mechagon Island, Unit 17
    {1462,154927,1462,7,56398,"battlepet:2740:25:5:1801:420:234"}, -- Mechagon Island, Unit 35
    -- Nazjatar (1355)
    {1355,154911,1355,7,56382,"battlepet:2724:25:5:1840:420:347"}, -- Nazjatar, Chomp
    {1355,154915,1355,7,56386,"battlepet:2728:25:5:1723:420:356"}, -- Nazjatar, Elderspawn of Nalaada
    {1355,154920,1355,7,56391,"battlepet:2733:25:5:1801:435:263"}, -- Nazjatar, Frenzied Knifefang
    {1355,154921,1355,7,56392,"battlepet:2734:25:5:1840:435:366"}, -- Nazjatar, Giant Opaline Conch
    {1355,154918,1355,7,56389,"battlepet:2731:25:5:1958:420:375"}, -- Nazjatar, Kelpstone
    {1355,154917,1355,7,56388,"battlepet:2730:25:5:1879:420:323"}, -- Nazjatar, Mindshackle
    {1355,154914,1355,7,56385,"battlepet:2727:25:5:1879:405:356"}, -- Nazjatar, Pearlhusk Crawler
    {1355,154910,1355,7,56381,"battlepet:2723:25:5:1684:330:338"}, -- Nazjatar, Prince Wiggletail
    {1355,154916,1355,7,56387,"battlepet:2729:25:5:1879:435:319"}, -- Nazjatar, Ravenous Scalespawn
    {1355,154913,1355,7,56384,"battlepet:2726:25:5:1801:390:272"}, -- Nazjatar, Shadowspike Lurker
    {1355,154912,1355,7,56383,"battlepet:2725:25:5:1723:420:281"}, -- Nazjatar, Silence
    {1355,154919,1355,7,56390,"battlepet:2732:25:5:1840:405:342"}, -- Nazjatar, Voltgorger
    -- Kul Tiras (876)
    {876,139489,896,7,52009,"battlepet:2193:25:3:1587:289:252","battlepet:2194:25:3:1380:333:256","battlepet:2195:25:3:1546:256:293"}, -- Kul Tiras, Captain Hermes (Shelly, Sheldon, Shelby)
    {876,140461,896,7,52218,"battlepet:2209:25:3:1400:260:325","battlepet:2206:25:3:1400:289:289","battlepet:2208:25:3:1684:276:268"}, -- Kul Tiras, Dilbert McClint (Atherton, Bybee, Jennings)
    {876,140813,896,7,52278,"battlepet:2210:25:3:1465:289:273","battlepet:2211:25:3:2131:260:260","battlepet:2212:25:3:2131:260:260"}, -- Kul Tiras, Fizzie Sparkwhistle (Azerite Slime, Azerite Geode, Azerite Elemental)
    {876,140880,896,7,52297,"battlepet:2213:25:3:5462:260:325","battlepet:2214:25:3:5462:260:325","battlepet:2215:25:3:5462:260:325"}, -- Kul Tiras, Michael Skarn (Bumble B., Fris B., Busy B.)
    {876,139987,942,7,52126,"battlepet:2200:25:4:2999:189:236"}, -- Kul Tiras, Bristlespine
    {876,140315,942,7,52165,"battlepet:2205:25:3:2765:249:219","battlepet:2203:25:3:2765:249:219","battlepet:2204:25:3:2765:249:219"}, -- Kul Tiras, Eddie Fixit ("Upgraded" Nightmare Weaver, "Repaired" Portable Fire Starter, "Fixed" Remote Control Rocket Chicken)
    {876,141002,942,7,52316,"battlepet:2220:25:3:1668:273:330","battlepet:2221:25:3:1603:366:179","battlepet:2222:25:3:1684:317:317"}, -- Kul Tiras, Ellie Vern (Dead Deckhand Leonard, Corrupted Slime, Reanimated Kraken Tentacle)
    {876,141046,942,7,52325,"battlepet:2223:25:3:1546:330:301","battlepet:2225:25:3:1546:330:301","battlepet:2226:25:3:1546:289:341"}, -- Kul Tiras, Leana Darkwind (Lesser Charged Gale, Lesser Twisted Current, Mind Warper)
    {876,141479,895,7,52751,"battlepet:2330:25:3:1709:249:292","battlepet:2332:25:3:1546:322:292","battlepet:2333:25:3:1969:260:260"}, -- Kul Tiras, Burly (Timbo, Pokey, Burly Jr.)
    {876,141215,895,7,52455,"battlepet:2230:25:4:1177:294:367"}, -- Kul Tiras, Chitara
    {876,141292,895,7,52471,"battlepet:2233:25:3:1709:338:236","battlepet:2232:25:3:1546:284:322","battlepet:2231:25:3:1562:289:322"}, -- Kul Tiras, Delia Hanako (Fungus, Murray, Old Blue)
    {876,141077,895,7,52430,"battlepet:2229:25:3:1952:370:260","battlepet:2228:25:3:1952:289:341","battlepet:2227:25:3:1952:370:260"}, -- Kul Tiras, Kwint (Chum, Bruce, Maws Jr.)
    -- Zandalar (875)
    {875,141879,864,7,52850,"battlepet:2345:25:3:1522:289:330","battlepet:2346:25:3:1542:317:276","battlepet:2347:25:3:1725:272:301"}, -- Zandalar, Keeyo (Buzzbeak, Tikka, Milo)
    {875,142054,864,7,52878,"battlepet:2359:25:3:1749:273:285","battlepet:2357:25:3:1542:288:288","battlepet:2358:25:3:1542:288:288"}, -- Zandalar, Kusa (Beets, Rawly, Stinger)
    {875,141945,864,7,52856,"battlepet:2355:25:3:1400:97:406","battlepet:2354:25:3:2050:260:260","battlepet:2353:25:3:1709:322:260"}, -- Zandalar, Sizzik (Clubber, Squirt, Squeezer)
    {875,141969,864,7,52864,"battlepet:2356:25:3:2574:231:285"}, -- Zandalar, Spineleaf
    {875,141588,863,7,52779,"battlepet:2337:25:3:2642:218:273"}, -- Zandalar, Bloodtusk
    {875,141799,863,7,52799,"battlepet:2338:25:3:1400:330:330","battlepet:2339:25:3:1400:330:330","battlepet:2340:25:3:1400:330:330"}, -- Zandalar, Grady Prett (Delta, Scars, Little Blue)
    {875,141814,863,7,52803,"battlepet:2341:25:3:1831:260:330","battlepet:2343:25:3:1400:349:301","battlepet:2344:25:3:1668:260:330"}, -- Zandalar, Korval Darkbeard (Feathers, Splat, Brite)
    {875,141529,863,7,52754,"battlepet:2334:25:3:1546:260:338","battlepet:2335:25:3:1400:314:313","battlepet:2336:25:3:1400:374:260"}, -- Zandalar, Lozu (Lilly, Molaze, Ticker)
    {875,142151,862,7,52937,"battlepet:2367:25:3:2980:218:273"}, -- Zandalar, Jammer
    {875,142096,862,7,52892,"battlepet:2360:25:3:1749:297:285","battlepet:2361:25:3:1668:260:313","battlepet:2363:25:3:1481:260:357"}, -- Zandalar, Karaga (Lazy, Spokes, Skeeto)
    {875,142114,862,7,52923,"battlepet:2364:25:3:1400:284:337","battlepet:2365:25:3:1526:314:285","battlepet:2366:25:3:2131:260:260"}, -- Zandalar, Talia Sparkbrow (Eighty Eight, Turbo, Whiplash)
    {875,142234,862,7,52938,"battlepet:2368:25:3:1546:273:330","battlepet:2370:25:3:1607:330:260","battlepet:2371:25:3:1400:284:349"}, -- Zandalar, Zujai (Scales, Breaker, Stickers)
    -- The Deadmines (836)
    {836,119409,836,6,46292,"battlepet:2031:25:4:1745:319:280"}, -- The Deadmines, Foe Reaper 50
    {836,119346,836,6,46292,"battlepet:2023:25:2:1258:226:240","battlepet:2038:25:1:1000:207:259","battlepet:2039:25:1:1160:185:245"}, -- The Deadmines, Unfortunate Defias
    {836,119342,836,6,46292,"battlepet:2027:25:2:1320:192:267","battlepet:2038:25:1:1000:207:259","battlepet:2040:25:1:1160:196:234"}, -- The Deadmines, Angry Geode
    {836,119341,836,6,46292,"battlepet:2028:25:3:1302:231:289","battlepet:2039:25:1:1160:185:245","battlepet:2038:25:1:1000:207:259"}, -- The Deadmines, Mining Monkey
    {836,119408,836,6,46292,"battlepet:2033:25:4:1745:305:250"}, -- The Deadmines, "Captain" Klutz
    {836,119343,836,6,46292,"battlepet:2026:25:2:1208:240:240","battlepet:2039:25:1:1160:185:245","battlepet:2039:25:1:1160:185:245"}, -- The Deadmines, Klutz's Battle Rat
    {836,119345,836,6,46292,"battlepet:2024:25:2:1208:214:267","battlepet:2038:25:1:1000:207:259","battlepet:2038:25:1:1000:207:259"}, -- The Deadmines, Klutz's Battle Monkey
    {836,119344,836,6,46292,"battlepet:2025:25:2:1145:214:282","battlepet:2039:25:1:1160:185:245","battlepet:2040:25:1:1160:196:234"}, -- The Deadmines, Klutz's Battle Bird
    {836,119407,836,6,46292,"battlepet:2032:25:5:2036:278:300"}, -- The Deadmines, Cookie's Leftovers
    -- Wailing Caverns (825)
    {825,116786,825,6,45539,"battlepet:1989:25:1:1000:220:220","battlepet:1989:25:1:1000:220:220","battlepet:1988:25:1:1103:196:220"}, -- Wailing Caverns, Deviate Smallclaw
    {825,116788,825,6,45539,"battlepet:1988:25:1:1103:196:220","battlepet:1988:25:1:1103:196:220","battlepet:1988:25:1:1103:196:220"}, -- Wailing Caverns, Deviate Chomper
    {825,116787,825,6,45539,"battlepet:1987:25:1:1045:196:231","battlepet:1989:25:1:1000:220:220","battlepet:1987:25:1:1045:196:231"}, -- Wailing Caverns, Deviate Flapper
    {825,116789,825,6,45539,"battlepet:1990:25:4:1745:305:294","battlepet:1987:25:1:1045:196:231","battlepet:1989:25:1:1000:220:220"}, -- Wailing Caverns, Son of Skum
    {825,116792,825,6,45539,"battlepet:1993:25:2:1258:226:267","battlepet:1989:25:1:1000:220:220","battlepet:1989:25:1:1000:220:220"}, -- Wailing Caverns, Phyxia
    {825,116791,825,6,45539,"battlepet:1992:25:2:1320:216:267","battlepet:1988:25:1:1103:196:220","battlepet:1989:25:1:1000:220:220"}, -- Wailing Caverns, Dreadcoil
    {825,116790,825,6,45539,"battlepet:1991:25:2:1208:216:300","battlepet:1987:25:1:1045:196:231","battlepet:1987:25:1:1045:196:231"}, -- Wailing Caverns, Vilefang
    {825,116793,825,6,45539,"battlepet:1994:25:4:1614:319:311","battlepet:1988:25:1:1103:196:220","battlepet:1987:25:1:1045:196:231"}, -- Wailing Caverns, Hiss
    {825,116794,825,6,45539,"battlepet:1995:25:3:1437:260:276","battlepet:1987:25:1:1045:196:231","battlepet:1988:25:1:1103:196:220"}, -- Wailing Caverns, Growing Ectoplasm
    {825,116795,825,6,45539,"battlepet:1996:25:5:2231:353:300","battlepet:1987:25:1:1045:196:231","battlepet:1988:25:1:1103:196:220"}, -- Wailing Caverns, Budding Everliving Spore
    -- Argus (905)
    {905,128020,885,6,49054,"battlepet:2108:25:5:1879:540:291"}, -- Argus, Bloat
    {905,128021,885,6,49055,"battlepet:2109:25:5:1958:525:309"}, -- Argus, Earseeker
    {905,128023,885,6,49057,"battlepet:2111:25:5:2192:555:225"}, -- Argus, Minixis
    {905,128024,885,6,49058,"battlepet:2110:25:5:2114:495:281"}, -- Argus, One-of-Many
    {905,128022,885,6,49056,"battlepet:2112:25:5:2153:488:263"}, -- Argus, Pilfer
    {905,128019,885,6,49053,"battlepet:2107:25:5:1801:555:413"}, -- Argus, Watcher
    {905,128009,830,6,49043,"battlepet:2097:25:5:1997:518:309"}, -- Argus, Baneglow
    {905,128011,830,6,49045,"battlepet:2099:25:5:2075:503:356"}, -- Argus, Deathscreech
    {905,128008,830,6,49042,"battlepet:2096:25:5:1840:548:384"}, -- Argus, Foulclaw
    {905,128012,830,6,49046,"battlepet:2100:25:5:1997:518:328"}, -- Argus, Gnasher
    {905,128010,830,6,49044,"battlepet:2098:25:5:2114:495:319"}, -- Argus, Retch
    {905,128007,830,6,49041,"battlepet:2095:25:5:1919:533:384"}, -- Argus, Ruinhoof
    {905,128013,882,6,49047,"battlepet:2101:25:5:1958:525:338"}, -- Argus, Bucky
    {905,128017,882,6,49051,"battlepet:2105:25:5:1919:533:291"}, -- Argus, Corrupted Blood of Argus
    {905,128015,882,6,49049,"battlepet:2103:25:5:2036:510:300"}, -- Argus, Gloamwing
    {905,128018,882,6,49052,"battlepet:2106:25:5:2075:503:347"}, -- Argus, Mar'cuus
    {905,128016,882,6,49050,"battlepet:2104:25:5:2036:510:328"}, -- Argus, Shadeflicker
    {905,128014,882,6,49048,"battlepet:2102:25:5:1879:540:375"}, -- Argus, Snozz
    -- Broken Shore (646)
    {646,117950,646,6,46112,"battlepet:2011:25:4:1456:280:359","battlepet:2012:25:4:1570:311:294","battlepet:2013:25:4:1587:297:297"}, -- Broken Shore, Madam Viciosa (Imply, Rover, Seduction)
    {646,117951,646,6,46113,"battlepet:2008:25:4:1614:303:294","battlepet:2009:25:4:1500:350:280","battlepet:2010:25:4:1745:311:262"}, -- Broken Shore, Nameless Mystic (Fido, Seer's Eye, Flickering Fel)
    {646,117934,646,6,46111,"battlepet:2014:25:4:1657:294:294","battlepet:2015:25:4:1657:311:280","battlepet:2016:25:4:1657:311:280"}, -- Broken Shore, Sissix (Living Pool, Tia Mia and Larry, Rock Lobster)
    -- Azsuna (630)
    {630,98489,630,6,40310,"battlepet:1781:25:4:1570:315:294","battlepet:1782:25:4:1657:320:271","battlepet:1780:25:4:1657:276:315"}, -- Azsuna, Shipwrecked Captive (Scuttles, Clamps, Kiazor the Destroyer)
    {630,106476,630,6,42146,"battlepet:1893:25:3:1481:276:276","battlepet:1894:25:3:1481:276:276","battlepet:1892:25:3:1481:276:276"}, -- Azsuna, Beguiling Orb (Allured Tadpole, Confused Tadpole, Subjugated Tadpole)
    {630,105898,630,6,42063,"battlepet:1883:25:4:2999:270:240"}, -- Azsuna, Blottis
    {630,97323,630,6,42165,"battlepet:1731:25:0:854:178:235","battlepet:647:25:0:916:178:223","battlepet:706:25:0:916:178:223"}, -- Azsuna, Felspider
    {630,106552,630,6,42159,"battlepet:1897:25:3:1465:289:273","battlepet:1898:25:3:1806:276:227","battlepet:1899:25:3:1400:325:260"}, -- Azsuna, Nightwatcher Merayl (Breezy Book, Helpful Spirit, Delicate Moth)
    {630,106417,630,6,42148,"battlepet:1891:25:4:2343:350:280","battlepet:478:25:2:1258:192:252","battlepet:1583:25:2:1020:264:225"}, -- Azsuna, Vinu
    {630,106542,630,6,42154,"battlepet:1895:25:4:2007:355:294","battlepet:1896:25:4:2095:324:311"}, -- Azsuna, Wounded Azurewing Whelpling (Hungry Owl, Hungry Rat)
    -- Dalaran (627)
    {627,107489,627,6,42442,"battlepet:1905:25:3:1725:260:260","battlepet:1904:25:3:1400:260:325","battlepet:1906:25:3:1400:325:260"}, -- Dalaran, Amalia (Foof, Stumpers, Lil' Sizzle)
    {627,99210,627,6,40299,"battlepet:1800:25:3:1627:289:244","battlepet:1801:25:3:1481:244:325","battlepet:1799:25:3:1481:276:276"}, -- Dalaran, Bodhi Sunwayver (Itchy, Salty Bird, Grommet)
    {627,99742,627,6,41881,"battlepet:1815:25:5:2176:305:315"}, -- Dalaran, Heliosus
    {627,99182,627,6,40298,"battlepet:1795:25:4:1552:308:304","battlepet:1796:25:4:1500:329:294","battlepet:1797:25:4:1570:329:276"}, -- Dalaran, Sir Galveston (Sir Murkeston, Coach, Greatest Foe)
    {627,105241,627,6,41886,"battlepet:1855:25:5:1883:440:329"}, -- Dalaran, Splint Jr.
    {627,105840,627,6,42062,"battlepet:1880:25:4:3873:308:227"}, -- Dalaran, Stitches Jr. Jr.
    {627,97804,627,6,40277,"battlepet:1748:25:4:1482:297:329","battlepet:1746:25:4:1762:262:315","battlepet:1745:25:4:1482:276:346"}, -- Dalaran, Tiffany Nelson (Jinx, Rocket, Marshmallow)
    -- Highmountain (650)
    {650,99077,650,6,40280,"battlepet:1790:25:4:1587:332:280","battlepet:1791:25:4:1657:280:374","battlepet:1792:25:4:1614:320:276"}, -- Highmountain, Bredda Tenderhide (Lil' Spirit Guide, Quillino, Fethyr)
    {650,99150,650,6,40282,"battlepet:1798:25:4:1745:262:311","battlepet:1793:25:4:1587:297:297","battlepet:1794:25:4:1587:367:245"}, -- Highmountain, Grixis Tinypop (Gulp, Egcellent, Red Wire)
    {650,104782,650,6,41766,"battlepet:1843:25:4:1796:249:311","battlepet:1441:25:0:1062:158:210","battlepet:391:25:0:968:150:238"}, -- Highmountain, Hungry Icefang
    {650,105841,650,6,42064,"battlepet:1881:25:4:2416:342:267"}, -- Highmountain, Lil'idan
    {650,104553,659,6,41687,"battlepet:1842:25:3:1790:289:208","battlepet:1841:25:3:1790:305:195","battlepet:1840:25:3:1790:289:208"}, -- Highmountain, Odrogg (Rocklick, Slow Moe, Snot)
    {650,98572,656,6,41624,"battlepet:1811:25:5:1645:240:300"}, -- Highmountain, Rocko
    -- Stormheim (634)
    {634,105842,634,6,42067,"battlepet:1882:25:4:2999:259:245"}, -- Stormheim, Chromadon
    {634,105512,634,6,41948,"battlepet:1871:25:5:2069:319:263","battlepet:1872:25:5:2069:319:263"}, -- Stormheim, Envoy of the Hunt (Harbinger of Dark, Herald of Light)
    {634,99878,634,6,41958,"battlepet:1816:25:4:1587:297:210","battlepet:1817:25:4:1587:297:210","battlepet:1818:25:4:1587:297:210"}, -- Stormheim, Ominitron Defense System (Mini Magmatron, Mini Arcanotron, Mini Electron)
    {634,98270,634,6,40278,"battlepet:1770:25:4:1762:315:245","battlepet:1772:25:4:1657:311:280","battlepet:1771:25:4:1570:280:329"}, -- Stormheim, Robert Craig (Thrugtusk, Wumpas, Baeloth)
    {634,105387,634,6,41935,"battlepet:1867:25:4:1850:280:280"}, -- Stormheim, Andurs (Mini Musken)
    {634,105386,634,6,41935,"battlepet:1866:25:4:1500:350:280"}, -- Stormheim, Rydyr (Baby Bjorn)
    {634,105455,634,6,41944,"battlepet:1868:25:3:1627:260:289","battlepet:1869:25:3:1546:297:252","battlepet:1870:25:3:1465:289:273"}, -- Stormheim, Trapper Jarrun (Mist Wraith, Crawdead, Gnaw)
    -- Suramar (680)
    {680,97709,680,6,40337,"battlepet:1742:25:5:2163:413:272"}, -- Suramar, Master Tamer Flummox
    {680,105352,680,6,41931,"battlepet:1863:25:3:1339:272:325","battlepet:1864:25:3:1664:272:260","battlepet:1865:25:3:1339:337:260"}, -- Suramar, Surging Mana Crystal (Font of Mana, Seed of Mana, Essence of Mana)
    {680,105323,680,6,41914,"battlepet:1860:25:4:1745:311:329","battlepet:1861:25:3:1546:305:244","battlepet:1862:25:3:1644:260:276"}, -- Suramar, Ancient Catacomb Eggs (Ancient Catacomb Spider, Catacomb Bat, Catacomb Snake)
    {680,105250,680,6,41895,"battlepet:1857:25:4:1587:297:297","battlepet:1858:25:4:1570:303:303","battlepet:1859:25:4:1587:297:297"}, -- Suramar, Aulier (Beauty, Conviction, Dignity)
    {680,105674,680,6,41990,"battlepet:1873:25:3:1546:289:289","battlepet:1874:25:3:1481:305:289","battlepet:1875:25:3:1627:289:276"}, -- Suramar, Varenne (Gusteau, Remy, Dinner)
    {680,105779,680,6,42015,"battlepet:1877:25:4:1745:294:280","battlepet:1878:25:4:1657:294:294","battlepet:1879:25:4:1587:294:311"}, -- Suramar, Felsoul Seer (Eye of Inquisition, Eye of Interrogation, Eye of Impetration)
    -- Val'sharah (641)
    {641,99035,641,6,40279,"battlepet:1789:25:3:1709:257:257","battlepet:1787:25:3:1522:276:268","battlepet:1788:25:3:1562:260:276"}, -- Val'sharah, Durian Strongfruit (Sunny, Roots, Beaky)
    {641,105093,641,6,41862,"battlepet:1851:25:3:1319:305:289","battlepet:1852:25:3:1465:289:273","battlepet:1853:25:3:1831:265:227"}, -- Val'sharah, Fragment of Fire (Cackling Flame, Devouring Blaze, Living Coals)
    {641,97511,641,6,42190,"battlepet:1734:25:1:1045:174:259","battlepet:393:25:2:1195:178:282","battlepet:1583:25:2:1270:216:225"}, -- Val'sharah, Shimmering Aquafly
    {641,104992,641,6,41861,"battlepet:1849:25:5:1864:305:300"}, -- Val'sharah, The Maw
    {641,105009,641,6,41855,"battlepet:1850:25:4:1745:224:311","battlepet:479:25:1:1057:154:275","battlepet:393:25:0:1062:158:213"}, -- Val'sharah, Thistleleaf Bully
    {641,104970,641,6,41860,"battlepet:1847:25:3:1359:260:333","battlepet:1846:25:3:1400:289:289","battlepet:1848:25:3:1481:276:276"}, -- Val'sharah, Xorvasc (Trixy, Globs, Nightmare Sprout)
    -- Menagerie
    {L["Menagerie"],85622,582,5,37644,"battlepet:1479:25:3:2395:260:309","battlepet:1482:25:3:2497:276:244"}, -- Menagerie, Challenge Post (Brutus, Rukus)
    {L["Menagerie"],85517,582,5,37644,"battlepet:1483:25:3:1156:341:276","battlepet:1484:25:3:1481:276:276","battlepet:1485:25:3:1481:276:276"}, -- Menagerie, Challenge Post (Mr. Terrible, Carroteye, Sloppus)
    {L["Menagerie"],85659,582,5,37644,"battlepet:1486:25:3:3264:221:195"}, -- Menagerie, The Beakinator
    {L["Menagerie"],85624,582,5,37644,"battlepet:1488:25:3:2781:276:260","battlepet:1487:25:3:2781:284:252"}, -- Menagerie, Challenge Post (Queen Floret, King Floret)
    {L["Menagerie"],85625,582,5,37644,"battlepet:1489:25:3:2700:317:236","battlepet:1490:25:3:2497:317:276"}, -- Menagerie, Challenge Post (Kromli, Gromli)
    {L["Menagerie"],85626,582,5,37644,"battlepet:1492:25:3:1644:276:244","battlepet:1494:25:3:1481:276:276","battlepet:1493:25:3:1481:276:276"}, -- Menagerie, Challenge Post (Grubbles, Scrags, Stings)
    {L["Menagerie"],85627,582,5,37644,"battlepet:1496:25:3:1481:276:276","battlepet:1497:25:3:1420:284:280","battlepet:1498:25:3:1400:309:260"}, -- Menagerie, Challenge Post (Jahan, Samm, Archimedes)
    {L["Menagerie"],79751,582,5,37644,"battlepet:1409:25:3:3264:221:219"}, -- Menagerie, Eleanor
    {L["Menagerie"],85629,582,5,37644,"battlepet:1500:25:3:2375:260:292","battlepet:1499:25:3:2375:309:244"}, -- Menagerie, Challenge Post (Tirs, Fiero)
    {L["Menagerie"],85630,582,5,37644,"battlepet:1501:25:3:1806:244:244","battlepet:1502:25:3:1481:276:260","battlepet:1503:25:3:1562:292:244"}, -- Menagerie, Challenge Post (Rockbiter, Stonechewer, Acidtooth)
    {L["Menagerie"],85650,582,5,37644,"battlepet:1480:25:3:4000:276:256"}, -- Menagerie, Quintessence of Light
    {L["Menagerie"],85632,582,5,37644,"battlepet:1504:25:3:1359:252:317","battlepet:1505:25:3:1359:301:276","battlepet:1506:25:3:1359:301:276"}, -- Menagerie, Challenge Post (Blingtron 4999b, Protectron 022481, Protectron 011803)
    {L["Menagerie"],85685,582,5,37644,"battlepet:1507:25:3:3264:273:211"}, -- Menagerie, Stitches Jr.
    {L["Menagerie"],85634,582,5,37644,"battlepet:1508:25:3:1562:260:276","battlepet:1509:25:3:1481:301:236","battlepet:1510:25:3:1562:292:244"}, -- Menagerie, Challenge Post (Manos, Hanos, Fatos)
    {L["Menagerie"],79179,582,5,37644,"battlepet:1400:25:3:1237:309:292","battlepet:1401:25:3:1319:309:276","battlepet:1402:25:3:1481:252:301"}, -- Menagerie, Squirt (Deebs, Tyri, Puzzle)
    -- Garrison
    {L["Garrison"],91016,582,5,38299,"battlepet:1648:23:3:1356:266:251","battlepet:1651:23:2:1397:218:232","battlepet:1649:23:3:1520:269:209"}, -- Garrison, Erris the Collector (Sprouts, Prince Charming, Runts)
    {L["Garrison"],90675,582,5,38299,"battlepet:1640:23:3:1580:224:251","battlepet:1641:23:2:1273:235:235","battlepet:1642:23:3:1431:266:239"}, -- Garrison, Erris the Collector (Spores, Dusty, Salad)
    {L["Garrison"],91017,582,5,38299,"battlepet:1654:23:3:1240:262:281","battlepet:1653:23:3:1240:262:281","battlepet:1652:23:0:977:202:216"}, -- Garrison, Erris the Collector (Nicodemus, Brisby, Jenner)
    {L["Garrison"],91014,582,5,38299,"battlepet:1637:25:2:1273:235:235","battlepet:1643:25:3:1356:266:251","battlepet:1644:25:3:1431:266:239"}, -- Garrison, Erris the Collector (Moon, Mouthy, Carl)
    {L["Garrison"],91015,582,5,38299,"battlepet:1646:25:2:1204:221:276","battlepet:1645:25:2:1328:207:259","battlepet:1647:25:3:1221:311:236"}, -- Garrison, Erris the Collector (Enbi'see, Mal, Bones)
    {L["Garrison"],91363,590,5,38300,"battlepet:1648:23:3:1356:266:251","battlepet:1651:23:2:1397:218:232","battlepet:1649:23:3:1520:269:209"}, -- Garrison, Kura Thunderhoof (Sprouts, Prince Charming, Runts)
    {L["Garrison"],91026,590,5,38300,"battlepet:1640:23:3:1580:224:251","battlepet:1641:23:2:1273:235:235","battlepet:1642:23:3:1431:266:239"}, -- Garrison, Kura Thunderhoof (Spores, Dusty, Salad)
    {L["Garrison"],91364,590,5,38300,"battlepet:1654:23:3:1240:262:281","battlepet:1653:23:3:1240:262:281","battlepet:1652:23:0:977:202:216"}, -- Garrison, Kura Thunderhoof (Nicodemus, Brisby, Jenner)
    {L["Garrison"],91361,590,5,38300,"battlepet:1637:25:2:1273:235:235","battlepet:1643:25:3:1356:266:251","battlepet:1644:25:3:1431:266:239"}, -- Garrison, Kura Thunderhoof (Moon, Mouthy, Carl)
    {L["Garrison"],91362,590,5,38300,"battlepet:1646:25:2:1204:221:276","battlepet:1645:25:2:1328:207:259","battlepet:1647:25:3:1221:311:236"}, -- Garrison, Kura Thunderhoof (Enbi'see, Mal, Bones)
    {L["Garrison"],85420,582,5,36423,"battlepet:1473:25:3:1335:221:252"}, -- Garrison, Carrotus Maximus
    {L["Garrison"],89131,582,5,36423,"battlepet:1472:25:3:1166:221:292"}, -- Garrison, Gnawface
    {L["Garrison"],89130,582,5,36423,"battlepet:1474:25:3:1318:221:256"}, -- Garrison, Gorefu
    -- Draenor (572)
    {572,87124,539,5,37203,"battlepet:1547:25:3:1481:276:276","battlepet:1548:25:3:1969:260:211","battlepet:1549:25:3:1359:317:260"}, -- Draenor, Ashlei (Pixiebell, Doodle, Tally)
    {572,83837,543,5,37201,"battlepet:1443:25:5:1769:315:287","battlepet:1444:25:5:1694:319:300","battlepet:1424:25:5:1675:315:315"}, -- Draenor, Cymre Brightblade (Idol of Decay, Wishbright Lantern, Gyrexle, the Eternal Mechanic)
    {572,87122,525,5,37205,"battlepet:1550:25:3:1400:325:260","battlepet:1552:25:3:1400:260:325","battlepet:1553:25:3:1546:289:260"}, -- Draenor, Gargra (Wolfus, Fangra, Wolfgar)
    {572,87125,535,5,37208,"battlepet:1560:25:3:1546:379:260","battlepet:1561:25:3:1546:338:260","battlepet:1562:25:3:1546:354:260"}, -- Draenor, Taralune (Serendipity, Grace, Atonement)
    {572,87110,550,5,37206,"battlepet:1555:25:3:1546:289:260","battlepet:1554:25:3:1546:289:260","battlepet:1556:25:3:1928:301:179"}, -- Draenor, Tarr the Terrible (Gladiator Murkalot, Gladiator Deathy, Gladiator Murkimus)
    {572,87123,542,5,37207,"battlepet:1558:25:3:1546:289:260","battlepet:1559:25:3:1546:289:260","battlepet:1557:25:3:1400:325:260"}, -- Draenor, Vesharr (The Great Kaliri, Apexis Guardian, Darkwing)
    -- Tanaan Jungle (534)
    {534,94645,534,5,39168,"battlepet:1681:25:5:1801:255:413","battlepet:1468:25:2:1148:208:256","battlepet:1586:25:1:1103:176:245"}, -- Tanaan Jungle, Bleakclaw
    {534,94638,534,5,39161,"battlepet:1674:25:5:1411:368:366","battlepet:417:25:0:916:150:263","battlepet:1591:25:0:1010:158:223"}, -- Tanaan Jungle, Chaos Pup
    {534,94637,534,5,39160,"battlepet:1673:25:5:1801:330:319","battlepet:417:25:0:958:158:235","battlepet:1581:25:3:1369:234:244"}, -- Tanaan Jungle, Corrupted Thundertail
    {534,94639,534,5,39162,"battlepet:1675:25:5:1606:330:366","battlepet:1581:25:3:1099:286:244","battlepet:1468:25:3:1115:266:264"}, -- Tanaan Jungle, Cursed Spirit
    {534,94644,534,5,39167,"battlepet:1680:25:5:1997:255:366","battlepet:1468:25:2:1148:220:244","battlepet:1593:25:0:1010:150:235"}, -- Tanaan Jungle, Dark Gazer
    {534,94650,534,5,39173,"battlepet:1686:25:5:2192:255:319","battlepet:417:25:2:1145:192:270","battlepet:1591:25:0:968:160:225"}, -- Tanaan Jungle, Defiled Earth
    {534,94642,534,5,39165,"battlepet:1678:25:5:1606:293:413","battlepet:1581:25:3:1099:286:244","battlepet:1591:25:1:1103:174:245"}, -- Tanaan Jungle, Direflame
    {534,94647,534,5,39170,"battlepet:1683:25:5:1411:405:319","battlepet:417:25:0:968:160:225","battlepet:1593:25:2:1145:192:270"}, -- Tanaan Jungle, Dreadwalker
    {534,94640,534,5,39163,"battlepet:1676:25:5:1606:255:459","battlepet:450:25:1:1343:176:193","battlepet:450:25:1:1343:176:193"}, -- Tanaan Jungle, Felfly
    {534,94601,534,5,39157,"battlepet:1671:25:5:1997:293:319","battlepet:1586:25:1:1000:196:245","battlepet:1468:25:0:877:205:203"}, -- Tanaan Jungle, Felsworn Sentry
    {534,94643,534,5,39166,"battlepet:1679:25:5:1411:330:413","battlepet:483:25:0:1062:158:210","battlepet:483:25:3:1302:208:276"}, -- Tanaan Jungle, Mirecroak
    {534,94648,534,5,39171,"battlepet:1684:25:5:1606:368:319","battlepet:1586:25:2:1195:192:267","battlepet:1468:25:0:919:183:213"}, -- Tanaan Jungle, Netherfist
    {534,94649,534,5,39172,"battlepet:1685:25:5:1411:293:459","battlepet:1581:25:3:1369:234:244","battlepet:1581:25:3:1369:234:244"}, -- Tanaan Jungle, Skrillix
    {534,94641,534,5,39164,"battlepet:1677:25:5:1801:293:366","battlepet:417:25:0:1010:150:235","battlepet:1593:25:2:1145:192:270"}, -- Tanaan Jungle, Tainted Maulclaw
    {534,94646,534,5,39169,"battlepet:1682:25:5:1671:305:381","battlepet:483:25:1:1160:174:231","battlepet:1468:25:0:919:183:213"}, -- Tanaan Jungle, Vile Blood of Draenor
    -- Celestial Tournament (571)
    {571,71927,571,4,33137,"battlepet:1282:25:5:1600:381:287","battlepet:1281:25:5:1600:319:375","battlepet:1280:25:5:2069:300:281"}, -- Celestial Tournament, Chen Stormstout (Tonsa, Chirps, Brewly)
    {571,71931,571,4,33137,"battlepet:1295:25:5:1694:347:281","battlepet:1293:25:5:1694:300:319","battlepet:1292:25:5:1769:334:253"}, -- Celestial Tournament, Taran Zhu (Yen, Li, Bolo)
    {571,71924,571,4,33137,"battlepet:1299:25:5:1600:300:375","battlepet:1301:25:5:1975:300:300","battlepet:1300:25:5:1600:375:300"}, -- Celestial Tournament, Wrathion (Cindy, Alex, Dah'da)
    {571,71933,571,4,33137,"battlepet:1278:25:5:1600:384:272","battlepet:1279:25:5:2069:300:281","battlepet:1277:25:5:1694:300:356"}, -- Celestial Tournament, Blingtron 4000 (Au, Banks, Lil' B)
    {571,71930,571,4,33137,"battlepet:1288:25:5:2256:300:244","battlepet:1287:25:5:1600:413:272","battlepet:1286:25:5:1577:295:384"}, -- Celestial Tournament, Shademaster Kiryn (Nairn, Stormoen, Summer)
    {571,71932,571,4,33137,"battlepet:1296:25:5:2209:300:263","battlepet:1298:25:5:1600:375:300","battlepet:1297:25:5:1600:300:384"}, -- Celestial Tournament, Wise Mari (Carpe Diem, Spirus, River)
    {571,71934,571,4,33137,"battlepet:1269:25:5:1600:422:253","battlepet:1271:25:5:1694:300:338","battlepet:1268:25:5:2163:314:248"}, -- Celestial Tournament, Dr. Ion Goldbloom (Screamer, Chaos, Trike)
    {571,71926,571,4,33137,"battlepet:1285:25:5:1600:281:394","battlepet:1284:25:5:2209:300:253","battlepet:1283:25:5:1600:431:244"}, -- Celestial Tournament, Lorewalker Cho (Wisdom, Patience, Knowledge)
    {571,71929,571,4,33137,"battlepet:1291:25:5:1975:319:263","battlepet:1289:25:5:1600:431:263","battlepet:1290:25:5:1741:319:309"}, -- Celestial Tournament, Sully "The Pickle" McLeary (Socks, Monte, Rikki)
    {571,72285,571,4,33137,"battlepet:1311:25:5:1840:485:310"}, -- Celestial Tournament, Chi-Chi, Hatchling of Chi-Ji
    {571,72009,571,4,33137,"battlepet:1267:25:5:1840:485:296"}, -- Celestial Tournament, Xu-Fu, Cub of Xuen
    {571,72291,571,4,33137,"battlepet:1317:25:5:1840:485:287"}, -- Celestial Tournament, Yu'la, Broodling of Yu'lon
    {571,72290,571,4,33137,"battlepet:1319:25:5:2153:458:276"}, -- Celestial Tournament, Zao, Calfling of Niuzao
    -- Beasts of Fable
    {L["Beasts of Fable"],68558,422,4,32869,"battlepet:1187:25:5:1899:521:286"}, -- Beasts of Fable, Gorespine
    {L["Beasts of Fable"],68566,418,4,32868,"battlepet:1195:23:5:1664:414:345"}, -- Beasts of Fable, Skitterer Xi'a
    {L["Beasts of Fable"],68564,379,4,32604,"battlepet:1193:24:5:1868:429:284"}, -- Beasts of Fable, Dos-Ryga
    {L["Beasts of Fable"],68563,379,4,32604,"battlepet:1192:24:5:1886:458:280"}, -- Beasts of Fable, Kafi
    {L["Beasts of Fable"],68555,371,4,32604,"battlepet:1129:25:5:2020:492:281"}, -- Beasts of Fable, Ka'wi the Gorger
    {L["Beasts of Fable"],68565,371,4,32604,"battlepet:1194:24:5:1770:465:316"}, -- Beasts of Fable, Nitun
    {L["Beasts of Fable"],68562,388,4,32869,"battlepet:1191:24:5:2182:454:252"}, -- Beasts of Fable, Ti'un the Wanderer
    {L["Beasts of Fable"],68559,390,4,32869,"battlepet:1188:24:5:1864:450:297"}, -- Beasts of Fable, No-No
    {L["Beasts of Fable"],68560,376,4,32868,"battlepet:1189:25:5:2079:480:306"}, -- Beasts of Fable, Greyhoof
    {L["Beasts of Fable"],68561,376,4,32868,"battlepet:1190:25:5:1883:440:329"}, -- Beasts of Fable, Lucky Yi
    -- Pandaria (424)
    {424,176655,379,8,63435,"battlepet:3089:25:4:1500:280:350","battlepet:3090:25:4:1850:280:280","battlepet:3091:25:4:1500:350:280"}, -- Pandaria, Anthea (RT-3 M15, Squibbles, Churro)
    {424,162470,1530,7,58748,"battlepet:2860:25:5:2504:323:366"}, -- Pandaria, Baruk Stone Defender
    {424,162468,1530,7,58746,"battlepet:2858:25:5:2621:350:334"}, -- Pandaria, K'tiny the Mad
    {424,162469,1530,7,58747,"battlepet:2859:25:5:2856:413:141"}, -- Pandaria, Tormentius
    {424,162471,1530,7,58749,"battlepet:2861:25:5:3402:458:300"}, -- Pandaria, Vil'thik Hatchling
    {424,73626,554,4,33222,"battlepet:1339:25:5:2631:750:206"}, -- Pandaria, Little Tommy Newcomer (Lil' Oondasta)
    {424,68462,422,4,32439,"battlepet:1132:25:5:1600:300:375","battlepet:1133:25:5:1675:334:315","battlepet:1138:25:5:1769:300:334"}, -- Pandaria, Flowing Pandaren Spirit (Marley, Tiptoe, Pandaren Water Spirit)
    {424,66739,422,4,31957,"battlepet:1009:25:4:1657:311:280","battlepet:1008:25:4:1850:280:280","battlepet:1007:25:4:1500:350:280"}, -- Pandaria, Wastewalker Shu (Crusher, Pounder, Mutilator)
    {424,66733,418,4,31954,"battlepet:998:25:4:1657:280:311","battlepet:1000:25:4:1500:311:311","battlepet:999:25:4:1850:280:280"}, -- Pandaria, Mo'ruk (Woodcarver, Lightstalker, Needleback)
    {424,66738,379,4,31956,"battlepet:1003:25:4:1657:280:311","battlepet:1002:25:4:1657:280:311","battlepet:1001:25:4:1500:311:311"}, -- Pandaria, Courageous Yon (Piqua, Lapin, Bleat)
    {424,68465,379,4,32441,"battlepet:1141:25:5:1769:334:300","battlepet:1134:25:5:1769:300:334","battlepet:1137:25:5:1975:300:300"}, -- Pandaria, Thundering Pandaren Spirit (Pandaren Earth Spirit, Sludgy, Darnak the Tunneler)
    {424,66730,371,4,31953,"battlepet:994:25:4:1500:311:311","battlepet:993:25:4:1500:280:350","battlepet:992:25:4:1850:280:280"}, -- Pandaria, Hyuna of the Shrines (Skyshaper, Fangor, Dor the Wall)
    {424,68464,371,4,32440,"battlepet:1135:25:5:1769:315:315","battlepet:1136:25:5:1694:319:319","battlepet:1140:25:5:1694:319:319"}, -- Pandaria, Whispering Pandaren Spirit (Dusty, Whispertail, Pandaren Air Spirit)
    {424,68463,388,4,32434,"battlepet:1130:25:5:1600:334:334","battlepet:1139:25:5:1600:334:334","battlepet:1131:25:5:1675:315:334"}, -- Pandaria, Burning Pandaren Spirit (Crimson, Pandaren Fire Spirit, Glowy)
    {424,66918,388,4,31991,"battlepet:1006:25:4:1850:280:280","battlepet:1005:25:4:1657:280:311","battlepet:1004:25:4:1657:280:311"}, -- Pandaria, Seeker Zusshi (Diamond, Mollus, Skimmer)
    {424,66741,390,4,31958,"battlepet:1012:25:5:1600:300:375","battlepet:1011:25:5:1769:334:300","battlepet:1010:25:5:1600:334:334"}, -- Pandaria, Aki the Chosen (Chirrup, Stormlash, Whiskers)
    {424,66734,376,4,31955,"battlepet:997:25:4:1657:311:280","battlepet:996:25:4:1850:280:280","battlepet:995:25:4:1657:280:311"}, -- Pandaria, Farmer Nishi (Siren, Toothbreaker, Brood of Mothallus)
    -- Maelstrom (276)
    {276,66815,207,3,31973,"battlepet:985:25:4:1657:311:280","battlepet:984:25:4:1657:280:311","battlepet:983:25:4:1850:280:280"}, -- The Maelstrom, Bordin Steadyfist (Ruby, Crystallus, Fracture)
    -- Northrend (113)
    {113,115307,120,6,44767,"battlepet:1971:25:5:1647:352:343","battlepet:1972:25:5:1647:343:352","battlepet:1973:25:5:2069:319:262"}, -- Northrend, Algalon the Observer (Comet, Cosmos, Constellatius)
    {113,66635,117,2,31931,"battlepet:967:25:3:1400:289:289","battlepet:966:25:3:1546:260:289","battlepet:965:25:3:1481:276:276"}, -- Northrend, Beegle Blastfuse (Dinner, Gobbles, Warble)
    {113,66639,121,2,31934,"battlepet:976:25:3:1546:289:260","battlepet:975:25:3:1725:260:260","battlepet:974:25:3:1400:289:289"}, -- Northrend, Gutretch (Cadavus, Fleshrender, Blight)
    {113,66675,118,2,31935,"battlepet:979:25:4:1850:280:280","battlepet:978:25:4:1500:311:311","battlepet:977:25:4:1657:280:311"}, -- Northrend, Major Payne (Grizzle, Beakmaster X-225, Bloom)
    {113,66636,127,2,31932,"battlepet:970:25:3:1400:289:289","battlepet:969:25:3:1546:260:289","battlepet:968:25:3:1546:289:260"}, -- Northrend, Nearly Headless Jacob (Spooky Strangler, Stitch, Mort)
    {113,66638,115,2,31933,"battlepet:973:25:3:1400:289:289","battlepet:972:25:3:1546:260:289","battlepet:971:25:3:1546:289:260"}, -- Northrend, Okrut Dragonwaste (Drogar, Sleet, Rot)
    -- Outland (101)
    {101,66557,104,1,31926,"battlepet:964:24:3:1426:265:265","battlepet:963:24:3:1488:278:250","battlepet:962:24:3:1348:278:278"}, -- Outland, Bloodknight Antari (Arcanus, Jadefire, Netherbite)
    {101,66553,111,1,31925,"battlepet:961:23:2:1204:276:221","battlepet:960:23:2:1204:276:221","battlepet:959:23:2:1204:246:246"}, -- Outland, Morulu The Elder (Chomps, Gnasher, Cragmaw)
    {101,66552,107,1,31924,"battlepet:958:22:2:1222:224:224","battlepet:957:22:2:1156:235:235","battlepet:956:22:2:1420:211:211"}, -- Outland, Narrok (Prince Wart, Dramaticus, Stompy)
    {101,66550,100,1,31922,"battlepet:952:20:2:1168:214:192","battlepet:951:20:2:1168:214:192","battlepet:950:20:2:1300:192:192"}, -- Outland, Nicki Tinytech (ED-005, Goliath, Sploder)
    {101,66551,102,1,31923,"battlepet:955:21:2:1108:202:252","battlepet:954:21:2:1171:214:214","battlepet:953:21:2:1360:202:202"}, -- Outland, Ras'an (Glitterfly, Tripod, Fungor)
    -- Darkmoon Island (407)
    {407,67370,407,0,32175,"battlepet:1065:25:4:1587:329:276","battlepet:1067:25:4:1745:294:280","battlepet:1066:25:4:1570:311:294"}, -- Darkmoon Island, Jeremy Feasel (Judgment, Honky-Tonk, Fezwick)
    {407,85519,407,0,36471,"battlepet:1477:25:5:1600:334:315","battlepet:1476:25:5:1600:375:281","battlepet:1475:25:5:1975:300:281"}, -- Darkmoon Island, Christoph VonFeasel (Syd, Mr. Pointy, Otto)
    -- Kalimdor (12)
    {12,162465,1527,7,58743,"battlepet:2856:25:5:2840:395:403"}, -- Kalimdor, Aqir Sandcrawler
    {12,162466,1527,7,58745,"battlepet:2857:25:5:3246:278:375"}, -- Kalimdor, Blotto
    {12,162458,1527,7,58742,"battlepet:2854:25:5:3090:320:399"}, -- Kalimdor, Retinus the Seeker
    {12,162461,1527,7,58744,"battlepet:2855:25:5:2856:473:197"}, -- Kalimdor, Whispers
    {12,115286,10,6,45083,"battlepet:1983:25:4:1500:350:280","battlepet:1981:25:4:1500:280:350","battlepet:1982:25:4:1850:280:280"}, -- Kalimdor, Crysa (Cherry, Swoop, Buzz)
    {12,66819,198,3,31972,"battlepet:982:25:4:1500:280:350","battlepet:981:25:4:1500:311:311","battlepet:980:25:4:1850:280:280"}, -- Kalimdor, Brok (Kali, Ashtail, Incinderous)
    {12,66824,249,3,31971,"battlepet:991:25:4:1500:311:311","battlepet:990:25:4:1500:280:350","battlepet:989:25:4:1657:280:311"}, -- Kalimdor, Obalis (Pyth, Spring, Clatter)
    {12,66466,83,0,31909,"battlepet:929:19:2:1115:182:203","battlepet:928:19:2:1012:203:203","battlepet:927:19:2:1012:182:228"}, -- Kalimdor, Stone Cold Trixxy (Tinygos, Frostmaw, Blizzy)
    {12,66412,80,0,31908,"battlepet:926:17:2:916:182:182","battlepet:925:17:2:1008:182:163","battlepet:924:17:2:1008:163:181"}, -- Kalimdor, Elena Flutterfly (Willow, Beacon, Lacewing)
    {12,66442,77,0,31907,"battlepet:923:16:2:1108:144:154","battlepet:922:16:2:868:192:154","battlepet:921:16:2:954:171:154"}, -- Kalimdor, Zoltan (Hatewalker, Beamer, Ultramus)
    {12,66452,64,0,31906,"battlepet:917:15:2:1000:144:144","battlepet:916:15:2:820:160:160","battlepet:915:15:2:901:160:144"}, -- Kalimdor, Kela Grimtotem (Indigon, Plague, Cho'guana)
    {12,66436,70,0,31905,"battlepet:913:14:2:772:158:141","battlepet:912:14:2:772:176:126","battlepet:911:14:2:848:158:126"}, -- Kalimdor, Grazzle the Great (Blaze, Flameclaw, Firetooth)
    {12,66352,69,0,31871,"battlepet:906:13:2:724:125:156","battlepet:905:13:2:724:139:139","battlepet:904:13:2:794:125:139"}, -- Kalimdor, Traitor Gluk (Glimmer, Rasp, Prancer)
    {12,66422,199,0,31904,"battlepet:909:11:2:628:106:132","battlepet:908:11:2:628:117:117","battlepet:907:11:2:687:106:117"}, -- Kalimdor, Cassandra Kaboom (Gizmo, Cluckatron, Whirls)
    {12,66372,66,0,31872,"battlepet:902:9:1:541:79:88","battlepet:901:9:1:595:79:79","battlepet:900:9:1:595:79:79"}, -- Kalimdor, Merda Stronghoof (Bounder, Ambershell, Rockhide)
    {12,66137,65,0,31862,"battlepet:899:7:1:408:69:69","battlepet:898:7:1:427:65:65","battlepet:897:7:1:443:62:69"}, -- Kalimdor, Zonya the Sadist (Constrictor, Odoron, Acidous)
    {12,66136,63,0,31854,"battlepet:896:5:1:375:44:44","battlepet:895:5:1:320:49:49","battlepet:894:5:1:320:44:55"}, -- Kalimdor, Analynn (Mister Pinch, Oozer, Flutterby)
    {12,66135,10,0,31819,"battlepet:893:3:1:240:28:28","battlepet:892:3:1:232:29:29","battlepet:891:3:1:232:26:33"}, -- Kalimdor, Dagra the Fierce (Longneck, Springtail, Ripper)
    {12,66126,1,0,31818,"battlepet:890:2:1:194:19:19","battlepet:889:2:1:194:19:19"}, -- Kalimdor, Zunta (Spike, Mumtar)
    -- Eastern Kingdom (13)
    {13,124617,30,6,47895,"battlepet:2068:25:4:1920:346:241","battlepet:2067:25:4:1500:332:350","battlepet:2066:25:4:1789:297:311"}, -- Eastern Kingdoms, Environeer Bert (Corporal Hammer, M-37, Clamp)
    {13,66822,241,3,31974,"battlepet:988:25:4:1500:311:311","battlepet:987:25:4:1657:280:311","battlepet:986:25:4:1500:350:280"}, -- Eastern Kingdoms, Goz Banefury (Twilight, Amythel, Helios)
    {13,66522,42,0,31916,"battlepet:949:19:2:1012:203:203","battlepet:948:19:2:1012:182:228","battlepet:947:19:2:1115:182:203"}, -- Eastern Kingdoms, Lydia Accoste (Jack, Bishibosh, Nightstalker)
    {13,66520,36,0,31914,"battlepet:946:17:2:916:163:204","battlepet:945:17:2:1008:182:163","battlepet:944:17:2:1120:163:163"}, -- Eastern Kingdoms, Durin Darkhammer (Comet, Ignious, Moltar)
    {13,66518,51,0,31913,"battlepet:943:16:2:954:154:171","battlepet:942:16:2:1060:154:154","battlepet:941:16:2:868:171:171"}, -- Eastern Kingdoms, Everessa (Dampwing, Croaker, Anklor)
    {13,66515,32,0,31912,"battlepet:939:15:2:901:160:144","battlepet:938:15:2:901:144:160","battlepet:937:15:2:820:160:160"}, -- Eastern Kingdoms, Kortas Darkhammer (Garnestrasz, Veridia, Obsidion)
    {13,66512,23,0,31911,"battlepet:936:14:2:814:143:143","battlepet:935:14:2:772:150:150","battlepet:934:14:2:940:134:134"}, -- Eastern Kingdoms, Deiza Plaguehorn (Carrion, Bleakspinner, Plaguebringer)
    {13,66478,26,0,31910,"battlepet:933:13:2:724:125:156","battlepet:932:13:2:880:125:125","battlepet:931:13:2:794:125:139"}, -- Eastern Kingdoms, David Kosse (Subject 142, Corpsefeeder, Plop)
    {13,65656,210,0,31851,"battlepet:888:11:2:661:112:112","battlepet:887:11:2:628:117:117","battlepet:886:11:2:687:106:117"}, -- Eastern Kingdoms, Bill Buckler (Burgle, Eyegouger, Young Beaky)
    {13,63194,50,0,31852,"battlepet:885:9:1:496:88:88","battlepet:884:9:1:496:88:88","battlepet:883:9:1:595:79:79"}, -- Eastern Kingdoms, Steven Lisbane (Nanners, Moonstalker, Emeralda)
    {13,65655,47,0,31850,"battlepet:882:7:1:443:62:69","battlepet:881:7:1:408:69:69","battlepet:880:7:1:443:69:62"}, -- Eastern Kingdoms, Eric Davidson (Webwinder, Blackfang, Darkwidow)
    {13,65651,49,0,31781,"battlepet:879:5:1:345:49:44","battlepet:878:5:1:334:47:47","battlepet:877:5:1:345:44:49"}, -- Eastern Kingdoms, Lindsay (Flufftail, Dipsy, Flipsy)
    {13,65648,52,0,31780,"battlepet:876:3:1:247:29:26","battlepet:875:3:1:232:29:29","battlepet:874:3:1:240:28:28"}, -- Eastern Kingdoms, Old MacDonald (Foe Reaper 800, Clucks, Teensy)
    {13,64330,37,0,31693,"battlepet:873:2:1:194:19:19","battlepet:872:2:1:194:19:19"}, -- Eastern Kingdoms, Julia Stevens (Fangs, Slither)
}

-- table of npcID's and the npcID they should actually refer to
rematch.targetData.redirects = {
    [89129] = 85420, -- Carrotus Maximus at Frostwall -> Carrotus Maximus at Lunarfall
    [85463] = 89130, -- Gorefu Frostwall -> Gorefu at Lunarfall
    [85419] = 89131, -- Gnawface at Frostwall -> Gnawface at Lunarfall

    [99880] = 99878, -- Mini Magmatron golem -> Mini Magmatron console

    [105353] = 105352, -- Font of Mana -> Surging Mana Crystal
    [105356] = 105352, -- Seed of Mana -> Surging Mana Crystal
    [105355] = 105352, -- Essence of Mana -> Surging Mana Crystal

    [106535] = 106542, -- Hungry Rat -> Wounded Azurewing Whelpling
    [106525] = 106542, -- Hungry Owl -> Wounded Azurewing Whelpling

    [106422] = 106476, -- Subjugated Tadpole -> Beguiling Orb
    [106424] = 106476, -- Confused Tadpole -> Beguiling Orb
    [106423] = 106476, -- Allured Tadpole -> Beguiling Orb

    [105318] = 105323, -- Catacomb Spider -> Ancient Catacomb Eggs
    [105319] = 105323, -- Catacomb Bat -> Ancient Catacomb Eggs
    [105320] = 105323, -- Catacomb Snake -> Ancient Catacomb Eggs

    -- Stratholme "Plagued Critters" is a swarm. Targeting a rat/roach uses
    -- these creature IDs, but saved teams are stored on the encounter dummy.
    [150906] = 155145, -- Plague Roach -> Plagued Critters
    [150907] = 155145, -- Plague Rat -> Plagued Critters
    [150908] = 155145, -- Diseased Rat -> Plagued Critters

    -- Gnomeregan Door Control Console robots
    [146148] = 146932, -- Ultra Safe Napalm Carrier -> Door Control Console
    [146150] = 146932, -- Sludge Disposal Unit -> Door Control Console
    [146151] = 146932, -- Freeze Ray Robot Prototype -> Door Control Console

    -- Blackrock Depths Horu Cloudwatcher pets
    [161400] = 160209, -- Alpha -> Horu Cloudwatcher
    [161403] = 160209, -- Bomber -> Horu Cloudwatcher
    [161401] = 160209, -- Beta (adjacent id) -> Horu Cloudwatcher
    [161402] = 160209, -- Beta (adjacent id) -> Horu Cloudwatcher

    -- the following all redirect to their respective Challenge Post in the WoD Menagerie
    [85678] = 85629, -- Tirs
    [85677] = 85629, -- Fiero
    [85681] = 85630, -- Rockbiter
    [85680] = 85630, -- Stonechewer
    [85679] = 85630, -- Acidtooth
    [85682] = 85632, -- Blingtron 4999b
    [85683] = 85632, -- Protectron 022481
    [85684] = 85632, -- Protectron 011803
    [85686] = 85634, -- Manos
    [85687] = 85634, -- Hanos
    [85688] = 85634, -- Fatos
    [85561] = 85622, -- Brutus
    [85655] = 85622, -- Rukus
    [85656] = 85517, -- Mr. Terrible
    [85657] = 85517, -- Carroteye
    [85658] = 85517, -- Sloppus
    [85661] = 85624, -- Queen Floret
    [85660] = 85624, -- King Floret
    [85662] = 85625, -- Kromli
    [85663] = 85625, -- Gromli
    [85664] = 85626, -- Grubbles
    [85666] = 85626, -- Scrags
    [85665] = 85626, -- Stings
    [85674] = 85627, -- Jahan
    [85675] = 85627, -- Samm
    [85676] = 85627, -- Archimedes
}

-- Unique public phrases (gossip, scenario steps, criteria) -> notable npcID.
-- Used when dungeon secrets hide GUID/unit name but still show quest-like text.
rematch.targetData.publicTextHints = {
    ["swarm of plagued"] = 155145,
    ["plagued rats and cockroaches"] = 155145,
    ["extermination time"] = 155145,
    ["defeat the plagued critters"] = 155145,
    ["did that just come out of its mouth"] = 150923,
    ["it just wants to play"] = 150922,
    ["tormented spirits"] = 150925,
    ["tiny in size, brimming"] = 150929,
    ["no shortage of dead"] = 155267,
    ["the shadows return"] = 150858,
}

-- Unit names that should resolve to a notable npcID when the targeted unit is a
-- pack member rather than the encounter dummy (e.g. Stratholme Plagued Critters).
rematch.targetData.nameAliases = {
    ["Emeralda"] = 63194,
    ["Moonstalker"] = 63194,
    ["Nanners"] = 63194,
    ["Fangs"] = 64330,
    ["Slither"] = 64330,
    ["Clucks"] = 65648,
    ["Foe Reaper 800"] = 65648,
    ["Teensy"] = 65648,
    ["Dipsy"] = 65651,
    ["Flipsy"] = 65651,
    ["Flufftail"] = 65651,
    ["Blackfang"] = 65655,
    ["Darkwidow"] = 65655,
    ["Webwinder"] = 65655,
    ["Burgle"] = 65656,
    ["Eyegouger"] = 65656,
    ["Young Beaky"] = 65656,
    ["Mumtar"] = 66126,
    ["Spike"] = 66126,
    ["Longneck"] = 66135,
    ["Ripper"] = 66135,
    ["Springtail"] = 66135,
    ["Flutterby"] = 66136,
    ["Mister Pinch"] = 66136,
    ["Oozer"] = 66136,
    ["Acidous"] = 66137,
    ["Constrictor"] = 66137,
    ["Odoron"] = 66137,
    ["Glimmer"] = 66352,
    ["Prancer"] = 66352,
    ["Rasp"] = 66352,
    ["Ambershell"] = 66372,
    ["Bounder"] = 66372,
    ["Rockhide"] = 66372,
    ["Beacon"] = 66412,
    ["Lacewing"] = 66412,
    ["Willow"] = 66412,
    ["Cluckatron"] = 66422,
    ["Gizmo"] = 66422,
    ["Whirls"] = 66422,
    ["Blaze"] = 66436,
    ["Firetooth"] = 66436,
    ["Flameclaw"] = 66436,
    ["Beamer"] = 66442,
    ["Hatewalker"] = 66442,
    ["Ultramus"] = 66442,
    ["Cho'guana"] = 66452,
    ["Indigon"] = 66452,
    ["Plague"] = 66452,
    ["Blizzy"] = 66466,
    ["Frostmaw"] = 66466,
    ["Tinygos"] = 66466,
    ["Corpsefeeder"] = 66478,
    ["Plop"] = 66478,
    ["Subject 142"] = 66478,
    ["Bleakspinner"] = 66512,
    ["Carrion"] = 66512,
    ["Plaguebringer"] = 66512,
    ["Garnestrasz"] = 66515,
    ["Obsidion"] = 66515,
    ["Veridia"] = 66515,
    ["Anklor"] = 66518,
    ["Croaker"] = 66518,
    ["Dampwing"] = 66518,
    ["Ignious"] = 66520,
    ["Moltar"] = 66520,
    ["Bishibosh"] = 66522,
    ["Jack"] = 66522,
    ["Nightstalker"] = 66522,
    ["ED-005"] = 66550,
    ["Goliath"] = 66550,
    ["Sploder"] = 66550,
    ["Fungor"] = 66551,
    ["Glitterfly"] = 66551,
    ["Tripod"] = 66551,
    ["Dramaticus"] = 66552,
    ["Prince Wart"] = 66552,
    ["Stompy"] = 66552,
    ["Chomps"] = 66553,
    ["Cragmaw"] = 66553,
    ["Gnasher"] = 66553,
    ["Arcanus"] = 66557,
    ["Jadefire"] = 66557,
    ["Netherbite"] = 66557,
    ["Gobbles"] = 66635,
    ["Warble"] = 66635,
    ["Mort"] = 66636,
    ["Spooky Strangler"] = 66636,
    ["Stitch"] = 66636,
    ["Drogar"] = 66638,
    ["Rot"] = 66638,
    ["Sleet"] = 66638,
    ["Blight"] = 66639,
    ["Cadavus"] = 66639,
    ["Fleshrender"] = 66639,
    ["Beakmaster X-225"] = 66675,
    ["Bloom"] = 66675,
    ["Grizzle"] = 66675,
    ["Dor the Wall"] = 66730,
    ["Fangor"] = 66730,
    ["Skyshaper"] = 66730,
    ["Lightstalker"] = 66733,
    ["Needleback"] = 66733,
    ["Woodcarver"] = 66733,
    ["Brood of Mothallus"] = 66734,
    ["Siren"] = 66734,
    ["Toothbreaker"] = 66734,
    ["Bleat"] = 66738,
    ["Lapin"] = 66738,
    ["Piqua"] = 66738,
    ["Crusher"] = 66739,
    ["Mutilator"] = 66739,
    ["Chirrup"] = 66741,
    ["Stormlash"] = 66741,
    ["Whiskers"] = 66741,
    ["Crystallus"] = 66815,
    ["Fracture"] = 66815,
    ["Ruby"] = 66815,
    ["Ashtail"] = 66819,
    ["Incinderous"] = 66819,
    ["Kali"] = 66819,
    ["Amythel"] = 66822,
    ["Helios"] = 66822,
    ["Twilight"] = 66822,
    ["Clatter"] = 66824,
    ["Pyth"] = 66824,
    ["Spring"] = 66824,
    ["Diamond"] = 66918,
    ["Mollus"] = 66918,
    ["Skimmer"] = 66918,
    ["Fezwick"] = 67370,
    ["Honky-Tonk"] = 67370,
    ["Judgment"] = 67370,
    ["Marley"] = 68462,
    ["Pandaren Water Spirit"] = 68462,
    ["Tiptoe"] = 68462,
    ["Crimson"] = 68463,
    ["Glowy"] = 68463,
    ["Pandaren Fire Spirit"] = 68463,
    ["Dusty"] = 68464,
    ["Pandaren Air Spirit"] = 68464,
    ["Whispertail"] = 68464,
    ["Darnak the Tunneler"] = 68465,
    ["Pandaren Earth Spirit"] = 68465,
    ["Sludgy"] = 68465,
    ["Alex"] = 71924,
    ["Cindy"] = 71924,
    ["Dah'da"] = 71924,
    ["Knowledge"] = 71926,
    ["Patience"] = 71926,
    ["Wisdom"] = 71926,
    ["Brewly"] = 71927,
    ["Chirps"] = 71927,
    ["Tonsa"] = 71927,
    ["Monte"] = 71929,
    ["Rikki"] = 71929,
    ["Socks"] = 71929,
    ["Nairn"] = 71930,
    ["Stormoen"] = 71930,
    ["Summer"] = 71930,
    ["Bolo"] = 71931,
    ["Li"] = 71931,
    ["Yen"] = 71931,
    ["Carpe Diem"] = 71932,
    ["River"] = 71932,
    ["Spirus"] = 71932,
    ["Au"] = 71933,
    ["Banks"] = 71933,
    ["Lil' B"] = 71933,
    ["Chaos"] = 71934,
    ["Screamer"] = 71934,
    ["Trike"] = 71934,
    ["Lil' Oondasta"] = 73626,
    ["Gyrexle"] = 83837,
    ["Idol of Decay"] = 83837,
    ["Wishbright Lantern"] = 83837,
    ["Mr. Pointy"] = 85519,
    ["Otto"] = 85519,
    ["Syd"] = 85519,
    ["Gladiator Deathy"] = 87110,
    ["Gladiator Murkalot"] = 87110,
    ["Gladiator Murkimus"] = 87110,
    ["Fangra"] = 87122,
    ["Wolfgar"] = 87122,
    ["Wolfus"] = 87122,
    ["Apexis Guardian"] = 87123,
    ["Darkwing"] = 87123,
    ["The Great Kaliri"] = 87123,
    ["Doodle"] = 87124,
    ["Pixiebell"] = 87124,
    ["Tally"] = 87124,
    ["Atonement"] = 87125,
    ["Grace"] = 87125,
    ["Serendipity"] = 87125,
    ["Jinx"] = 97804,
    ["Marshmallow"] = 97804,
    ["Rocket"] = 97804,
    ["Baeloth"] = 98270,
    ["Thrugtusk"] = 98270,
    ["Wumpas"] = 98270,
    ["Clamps"] = 98489,
    ["Kiazor the Destroyer"] = 98489,
    ["Scuttles"] = 98489,
    ["Beaky"] = 99035,
    ["Roots"] = 99035,
    ["Sunny"] = 99035,
    ["Fethyr"] = 99077,
    ["Lil' Spirit Guide"] = 99077,
    ["Quillino"] = 99077,
    ["Egcellent"] = 99150,
    ["Gulp"] = 99150,
    ["Red Wire"] = 99150,
    ["Coach"] = 99182,
    ["Greatest Foe"] = 99182,
    ["Sir Murkeston"] = 99182,
    ["Grommet"] = 99210,
    ["Itchy"] = 99210,
    ["Salty Bird"] = 99210,
    ["Mini Arcanotron"] = 99878,
    ["Mini Electron"] = 99878,
    ["Mini Magmatron"] = 99878,
    ["Rocklick"] = 104553,
    ["Slow Moe"] = 104553,
    ["Snot"] = 104553,
    ["Globs"] = 104970,
    ["Nightmare Sprout"] = 104970,
    ["Trixy"] = 104970,
    ["Cackling Flame"] = 105093,
    ["Devouring Blaze"] = 105093,
    ["Living Coals"] = 105093,
    ["Beauty"] = 105250,
    ["Conviction"] = 105250,
    ["Dignity"] = 105250,
    ["Ancient Catacomb Spider"] = 105323,
    ["Catacomb Bat"] = 105323,
    ["Catacomb Snake"] = 105323,
    ["Essence of Mana"] = 105352,
    ["Font of Mana"] = 105352,
    ["Seed of Mana"] = 105352,
    ["Baby Bjorn"] = 105386,
    ["Mini Musken"] = 105387,
    ["Crawdead"] = 105455,
    ["Gnaw"] = 105455,
    ["Mist Wraith"] = 105455,
    ["Harbinger of Dark"] = 105512,
    ["Herald of Light"] = 105512,
    ["Gusteau"] = 105674,
    ["Remy"] = 105674,
    ["Eye of Impetration"] = 105779,
    ["Eye of Inquisition"] = 105779,
    ["Eye of Interrogation"] = 105779,
    ["Allured Tadpole"] = 106476,
    ["Confused Tadpole"] = 106476,
    ["Subjugated Tadpole"] = 106476,
    ["Hungry Owl"] = 106542,
    ["Hungry Rat"] = 106542,
    ["Breezy Book"] = 106552,
    ["Delicate Moth"] = 106552,
    ["Helpful Spirit"] = 106552,
    ["Foof"] = 107489,
    ["Lil' Sizzle"] = 107489,
    ["Stumpers"] = 107489,
    ["Buzz"] = 115286,
    ["Cherry"] = 115286,
    ["Swoop"] = 115286,
    ["Constellatius"] = 115307,
    ["Cosmos"] = 115307,
    ["Living Pool"] = 117934,
    ["Rock Lobster"] = 117934,
    ["Tia Mia and Larry"] = 117934,
    ["Imply"] = 117950,
    ["Rover"] = 117950,
    ["Seduction"] = 117950,
    ["Fido"] = 117951,
    ["Flickering Fel"] = 117951,
    ["Seer's Eye"] = 117951,
    ["Clamp"] = 124617,
    ["Corporal Hammer"] = 124617,
    ["M-37"] = 124617,
    ["Sheldon"] = 139489,
    ["Shelly"] = 139489,
    ["\"Fixed\" Remote Control Rocket Chicken"] = 140315,
    ["\"Repaired\" Portable Fire Starter"] = 140315,
    ["\"Upgraded\" Nightmare Weaver"] = 140315,
    ["Atherton"] = 140461,
    ["Bybee"] = 140461,
    ["Jennings"] = 140461,
    ["Azerite Elemental"] = 140813,
    ["Azerite Geode"] = 140813,
    ["Azerite Slime"] = 140813,
    ["Bumble B."] = 140880,
    ["Busy B."] = 140880,
    ["Fris B."] = 140880,
    ["Corrupted Slime"] = 141002,
    ["Dead Deckhand Leonard"] = 141002,
    ["Reanimated Kraken Tentacle"] = 141002,
    ["Lesser Charged Gale"] = 141046,
    ["Lesser Twisted Current"] = 141046,
    ["Mind Warper"] = 141046,
    ["Bruce"] = 141077,
    ["Chum"] = 141077,
    ["Maws Jr."] = 141077,
    ["Fungus"] = 141292,
    ["Murray"] = 141292,
    ["Old Blue"] = 141292,
    ["Burly Jr."] = 141479,
    ["Pokey"] = 141479,
    ["Timbo"] = 141479,
    ["Lilly"] = 141529,
    ["Molaze"] = 141529,
    ["Ticker"] = 141529,
    ["Delta"] = 141799,
    ["Little Blue"] = 141799,
    ["Scars"] = 141799,
    ["Feathers"] = 141814,
    ["Splat"] = 141814,
    ["Buzzbeak"] = 141879,
    ["Milo"] = 141879,
    ["Tikka"] = 141879,
    ["Clubber"] = 141945,
    ["Squeezer"] = 141945,
    ["Squirt"] = 141945,
    ["Beets"] = 142054,
    ["Rawly"] = 142054,
    ["Stinger"] = 142054,
    ["Lazy"] = 142096,
    ["Skeeto"] = 142096,
    ["Spokes"] = 142096,
    ["Eighty Eight"] = 142114,
    ["Turbo"] = 142114,
    ["Whiplash"] = 142114,
    ["Breaker"] = 142234,
    ["Scales"] = 142234,
    ["Stickers"] = 142234,
    ["Freeze Ray Robot Prototype"] = 146932,
    ["Sludge Disposal Unit"] = 146932,
    ["Ultra Safe Napalm Carrier"] = 146932,
    ["Diseased Rat"] = 155145,
    ["Plague Rat"] = 155145,
    ["Plague Roach"] = 155145,
    ["Lefty"] = 155413,
    ["Plagued Mailemental"] = 155413,
    ["Soul Collector"] = 155413,
    ["Infectus"] = 155414,
    ["Pyro"] = 155414,
    ["Smokey"] = 155414,
    ["Gigacharged Mayhem Maker"] = 160205,
    ["Frill"] = 160206,
    ["Ruddy"] = 160206,
    ["Wanderer"] = 160206,
    ["Logic"] = 160207,
    ["Math"] = 160207,
    ["Crushface"] = 160208,
    ["Fozling"] = 160208,
    ["Tremors"] = 160208,
    ["Alpha"] = 160209,
    ["Beta"] = 160209,
    ["Bomber"] = 160209,
    ["Fury"] = 160210,
    ["Glitzy"] = 160210,
    ["Presto"] = 160210,
    ["Golden Grazer"] = 173129,
    ["Plains Peachick"] = 173129,
    ["Sunset Glimmerfly"] = 173129,
    ["Battery"] = 173130,
    ["Slasher"] = 173130,
    ["Glitterwing"] = 173131,
    ["Tinyhoof"] = 173131,
    ["Bloog"] = 173257,
    ["Bone Crusher"] = 173257,
    ["Chipper"] = 173257,
    ["Leftovers"] = 173263,
    ["Stinkdust"] = 173267,
    ["Trailblazer"] = 173267,
    ["Whirly"] = 173267,
    ["Ash"] = 173315,
    ["Fang"] = 173315,
    ["Swarm"] = 173315,
    ["Boneclaw"] = 173324,
    ["Rocko"] = 173324,
    ["Spindler"] = 173324,
    ["Wretch"] = 173331,
    ["Duster"] = 173372,
    ["Runehoof"] = 173372,
    ["Slugger"] = 173372,
    ["Needlenose"] = 173377,
    ["Star Tail"] = 173377,
    ["Churro"] = 176655,
    ["RT-3 M15"] = 176655,
    ["Squibbles"] = 176655,
}

-- when targets share the same name and need a (sub name) to differentiate them; add them here
rematch.targetData.subnames = {
    [200684] = ITEM_QUALITY5_DESC, -- Vortex (Legendary)
    [200682] = ITEM_QUALITY4_DESC, -- Vortex (Epic)
    [200685] = ITEM_QUALITY3_DESC, -- Vortex (Rare)

    [200688] = ITEM_QUALITY5_DESC, -- Wildfire (Legendary)
    [200686] = ITEM_QUALITY4_DESC, -- Wildfire (Epic)
    [200689] = ITEM_QUALITY3_DESC, -- Wildfire (Rare)

    [200692] = ITEM_QUALITY5_DESC, -- Tremblor (Legendary)
    [200690] = ITEM_QUALITY4_DESC, -- Tremblor (Epic)
    [200693] = ITEM_QUALITY3_DESC, -- Tremblor (Rare)

    [200696] = ITEM_QUALITY5_DESC, -- Flow (Legendary)
    [200694] = ITEM_QUALITY4_DESC, -- Flow (Epic)
    [200697] = ITEM_QUALITY3_DESC, -- Flow (Rare)
}


-- lookup table of headerID = expansionID
rematch.targetData.headerExpansions = {}
for _,info in ipairs(rematch.targetData.notableTargets) do
    if info[1] and info[4] then
        rematch.targetData.headerExpansions["header:"..info[1]] =  info[4]
    end
end

-- WoW 12.1 compatibility: static names for notable targets.
-- Names are derived from the existing comments above.
rematch.targetData.targetNames = {
    [63194] = "Steven Lisbane",
    [64330] = "Julia Stevens",
    [65648] = "Old MacDonald",
    [65651] = "Lindsay",
    [65655] = "Eric Davidson",
    [65656] = "Bill Buckler",
    [66126] = "Zunta",
    [66135] = "Dagra the Fierce",
    [66136] = "Analynn",
    [66137] = "Zonya the Sadist",
    [66352] = "Traitor Gluk",
    [66372] = "Merda Stronghoof",
    [66412] = "Elena Flutterfly",
    [66422] = "Cassandra Kaboom",
    [66436] = "Grazzle the Great",
    [66442] = "Zoltan",
    [66452] = "Kela Grimtotem",
    [66466] = "Stone Cold Trixxy",
    [66478] = "David Kosse",
    [66512] = "Deiza Plaguehorn",
    [66515] = "Kortas Darkhammer",
    [66518] = "Everessa",
    [66520] = "Durin Darkhammer",
    [66522] = "Lydia Accoste",
    [66550] = "Nicki Tinytech",
    [66551] = "Ras'an",
    [66552] = "Narrok",
    [66553] = "Morulu The Elder",
    [66557] = "Bloodknight Antari",
    [66635] = "Beegle Blastfuse",
    [66636] = "Nearly Headless Jacob",
    [66638] = "Okrut Dragonwaste",
    [66639] = "Gutretch",
    [66675] = "Major Payne",
    [66730] = "Hyuna of the Shrines",
    [66733] = "Mo'ruk",
    [66734] = "Farmer Nishi",
    [66738] = "Courageous Yon",
    [66739] = "Wastewalker Shu",
    [66741] = "Aki the Chosen",
    [66815] = "Bordin Steadyfist",
    [66819] = "Brok",
    [66822] = "Goz Banefury",
    [66824] = "Obalis",
    [66918] = "Seeker Zusshi",
    [67370] = "Jeremy Feasel",
    [68462] = "Flowing Pandaren Spirit",
    [68463] = "Burning Pandaren Spirit",
    [68464] = "Whispering Pandaren Spirit",
    [68465] = "Thundering Pandaren Spirit",
    [68555] = "Ka'wi the Gorger",
    [68558] = "Gorespine",
    [68559] = "No-No",
    [68560] = "Greyhoof",
    [68561] = "Lucky Yi",
    [68562] = "Ti'un the Wanderer",
    [68563] = "Kafi",
    [68564] = "Dos-Ryga",
    [68565] = "Nitun",
    [68566] = "Skitterer Xi'a",
    [71924] = "Wrathion",
    [71926] = "Lorewalker Cho",
    [71927] = "Chen Stormstout",
    [71929] = "Sully \"The Pickle\" McLeary",
    [71930] = "Shademaster Kiryn",
    [71931] = "Taran Zhu",
    [71932] = "Wise Mari",
    [71933] = "Blingtron 4000",
    [71934] = "Dr. Ion Goldbloom",
    [72009] = "Xu-Fu, Cub of Xuen",
    [72285] = "Chi-Chi, Hatchling of Chi-Ji",
    [72290] = "Zao, Calfling of Niuzao",
    [72291] = "Yu'la, Broodling of Yu'lon",
    [73626] = "Little Tommy Newcomer",
    [79179] = "Squirt",
    [79751] = "Eleanor",
    [83837] = "Cymre Brightblade",
    [85420] = "Carrotus Maximus",
    [85517] = "Challenge Post",
    [85519] = "Christoph VonFeasel",
    [85622] = "Challenge Post",
    [85624] = "Challenge Post",
    [85625] = "Challenge Post",
    [85626] = "Challenge Post",
    [85627] = "Challenge Post",
    [85629] = "Challenge Post",
    [85630] = "Challenge Post",
    [85632] = "Challenge Post",
    [85634] = "Challenge Post",
    [85650] = "Quintessence of Light",
    [85659] = "The Beakinator",
    [85685] = "Stitches Jr.",
    [87110] = "Tarr the Terrible",
    [87122] = "Gargra",
    [87123] = "Vesharr",
    [87124] = "Ashlei",
    [87125] = "Taralune",
    [89130] = "Gorefu",
    [89131] = "Gnawface",
    [90675] = "Erris the Collector",
    [91014] = "Erris the Collector",
    [91015] = "Erris the Collector",
    [91016] = "Erris the Collector",
    [91017] = "Erris the Collector",
    [91026] = "Kura Thunderhoof",
    [91361] = "Kura Thunderhoof",
    [91362] = "Kura Thunderhoof",
    [91363] = "Kura Thunderhoof",
    [91364] = "Kura Thunderhoof",
    [94601] = "Felsworn Sentry",
    [94637] = "Corrupted Thundertail",
    [94638] = "Chaos Pup",
    [94639] = "Cursed Spirit",
    [94640] = "Felfly",
    [94641] = "Tainted Maulclaw",
    [94642] = "Direflame",
    [94643] = "Mirecroak",
    [94644] = "Dark Gazer",
    [94645] = "Bleakclaw",
    [94646] = "Vile Blood of Draenor",
    [94647] = "Dreadwalker",
    [94648] = "Netherfist",
    [94649] = "Skrillix",
    [94650] = "Defiled Earth",
    [97323] = "Felspider",
    [97511] = "Shimmering Aquafly",
    [97709] = "Master Tamer Flummox",
    [97804] = "Tiffany Nelson",
    [98270] = "Robert Craig",
    [98489] = "Shipwrecked Captive",
    [98572] = "Rocko",
    [99035] = "Durian Strongfruit",
    [99077] = "Bredda Tenderhide",
    [99150] = "Grixis Tinypop",
    [99182] = "Sir Galveston",
    [99210] = "Bodhi Sunwayver",
    [99742] = "Heliosus",
    [99878] = "Ominitron Defense System",
    [104553] = "Odrogg",
    [104782] = "Hungry Icefang",
    [104970] = "Xorvasc",
    [104992] = "The Maw",
    [105009] = "Thistleleaf Bully",
    [105093] = "Fragment of Fire",
    [105241] = "Splint Jr.",
    [105250] = "Aulier",
    [105323] = "Ancient Catacomb Eggs",
    [105352] = "Surging Mana Crystal",
    [105386] = "Rydyr",
    [105387] = "Andurs",
    [105455] = "Trapper Jarrun",
    [105512] = "Envoy of the Hunt",
    [105674] = "Varenne",
    [105779] = "Felsoul Seer",
    [105840] = "Stitches Jr. Jr.",
    [105841] = "Lil'idan",
    [105842] = "Chromadon",
    [105898] = "Blottis",
    [106417] = "Vinu",
    [106476] = "Beguiling Orb",
    [106542] = "Wounded Azurewing Whelpling",
    [106552] = "Nightwatcher Merayl",
    [107489] = "Amalia",
    [115286] = "Crysa",
    [115307] = "Algalon the Observer",
    [116786] = "Deviate Smallclaw",
    [116787] = "Deviate Flapper",
    [116788] = "Deviate Chomper",
    [116789] = "Son of Skum",
    [116790] = "Vilefang",
    [116791] = "Dreadcoil",
    [116792] = "Phyxia",
    [116793] = "Hiss",
    [116794] = "Growing Ectoplasm",
    [116795] = "Budding Everliving Spore",
    [117934] = "Sissix",
    [117950] = "Madam Viciosa",
    [117951] = "Nameless Mystic",
    [119341] = "Mining Monkey",
    [119342] = "Angry Geode",
    [119343] = "Klutz's Battle Rat",
    [119344] = "Klutz's Battle Bird",
    [119345] = "Klutz's Battle Monkey",
    [119346] = "Unfortunate Defias",
    [119407] = "Cookie's Leftovers",
    [119408] = "\"Captain\" Klutz",
    [119409] = "Foe Reaper 50",
    [124617] = "Environeer Bert",
    [128007] = "Ruinhoof",
    [128008] = "Foulclaw",
    [128009] = "Baneglow",
    [128010] = "Retch",
    [128011] = "Deathscreech",
    [128012] = "Gnasher",
    [128013] = "Bucky",
    [128014] = "Snozz",
    [128015] = "Gloamwing",
    [128016] = "Shadeflicker",
    [128017] = "Corrupted Blood of Argus",
    [128018] = "Mar'cuus",
    [128019] = "Watcher",
    [128020] = "Bloat",
    [128021] = "Earseeker",
    [128022] = "Pilfer",
    [128023] = "Minixis",
    [128024] = "One-of-Many",
    [139489] = "Captain Hermes",
    [139987] = "Bristlespine",
    [140315] = "Eddie Fixit",
    [140461] = "Dilbert McClint",
    [140813] = "Fizzie Sparkwhistle",
    [140880] = "Michael Skarn",
    [141002] = "Ellie Vern",
    [141046] = "Leana Darkwind",
    [141077] = "Kwint",
    [141215] = "Chitara",
    [141292] = "Delia Hanako",
    [141479] = "Burly",
    [141529] = "Lozu",
    [141588] = "Bloodtusk",
    [141799] = "Grady Prett",
    [141814] = "Korval Darkbeard",
    [141879] = "Keeyo",
    [141945] = "Sizzik",
    [141969] = "Spineleaf",
    [142054] = "Kusa",
    [142096] = "Karaga",
    [142114] = "Talia Sparkbrow",
    [142151] = "Jammer",
    [142234] = "Zujai",
    [145968] = "Leper Rat",
    [145971] = "Cockroach",
    [145988] = "Pulverizer Bot Mk 6001",
    [146001] = "Prototype Annoy-O-Tron",
    [146002] = "Gnomeregan Guard Wolf",
    [146003] = "Gnomeregan Guard Tiger",
    [146004] = "Gnomeregan Guard Mechanostrider",
    [146005] = "Bloated Leper Rat",
    [146181] = "Living Permafrost",
    [146182] = "Living Sludge",
    [146183] = "Living Napalm",
    [146932] = "Door Control Console",
    [150858] = "Blackmane",
    [150911] = "Crypt Fiend",
    [150914] = "Wandering Phantasm",
    [150917] = "Huncher",
    [150918] = "Tommy the Cruel",
    [150922] = "Sludge Belcher",
    [150923] = "Belchling",
    [150925] = "Liz the Tormentor",
    [150929] = "Nefarious Terry",
    [154910] = "Prince Wiggletail",
    [154911] = "Chomp",
    [154912] = "Silence",
    [154913] = "Shadowspike Lurker",
    [154914] = "Pearlhusk Crawler",
    [154915] = "Elderspawn of Nalaada",
    [154916] = "Ravenous Scalespawn",
    [154917] = "Mindshackle",
    [154918] = "Kelpstone",
    [154919] = "Voltgorger",
    [154920] = "Frenzied Knifefang",
    [154921] = "Giant Opaline Conch",
    [154922] = "Gnomefeaster",
    [154923] = "Sputtertube",
    [154924] = "Goldenbot XD",
    [154925] = "Creakclank",
    [154926] = "CK-9 Micro-Oppression Unit",
    [154927] = "Unit 35",
    [154928] = "Unit 6",
    [154929] = "Unit 17",
    [155145] = "Plagued Critters",
    [155267] = "Risen Guard",
    [155413] = "Postmaster Malown",
    [155414] = "Ezra Grimm",
    [160205] = "Pixy Wizzle",
    [160206] = "Alran Heartshade",
    [160207] = "Therin Skysong",
    [160208] = "Zuna Skullcrush",
    [160209] = "Horu Cloudwatcher",
    [160210] = "Tasha Riley",
    [161649] = "Rampage",
    [161650] = "Liz",
    [161651] = "Ralf",
    [161656] = "Splint",
    [161657] = "Ninn Jah",
    [161658] = "Shred",
    [161661] = "Wilbur",
    [161662] = "Char",
    [161663] = "Tempton",
    [162458] = "Retinus the Seeker",
    [162461] = "Whispers",
    [162465] = "Aqir Sandcrawler",
    [162466] = "Blotto",
    [162468] = "K'tiny the Mad",
    [162469] = "Tormentius",
    [162470] = "Baruk Stone Defender",
    [162471] = "Vil'thik Hatchling",
    [173129] = "Thenia",
    [173130] = "Zolla",
    [173131] = "Stratios",
    [173133] = "Jawbone",
    [173257] = "Caregiver Maximillian",
    [173263] = "Rotgut",
    [173267] = "Dundley Stickyfingers",
    [173274] = "Gorgemouth",
    [173303] = "Scorch",
    [173315] = "Sylla",
    [173324] = "Eyegor",
    [173331] = "Addius the Tormentor",
    [173372] = "Glitterdust",
    [173376] = "Nightfang",
    [173377] = "Faryl",
    [173381] = "Rascal",
    [175777] = "Crystalsnap",
    [175778] = "Briarpaw",
    [175779] = "Chittermaw",
    [175780] = "Mistwing",
    [175781] = "Sewer Creeper",
    [175782] = "The Countess",
    [175783] = "Digallo",
    [175784] = "Gelatinous",
    [175785] = "Kostos",
    [175786] = "Glurp",
    [176655] = "Anthea",
    [189376] = "Swog",
    [196069] = "Patchu",
    [196206] = "Gwosh",
    [196264] = "Haniko",
    [197102] = "Bakhushek",
    [197336] = "Enyobon",
    [197350] = "Setimothes",
    [197417] = "Arcantus",
    [197447] = "Stormamu",
    [200677] = "Storm-Touched Swoglet",
    [200678] = "Storm-Touched Slyvern",
    [200679] = "Storm-Touched Skitterer",
    [200680] = "Storm-Touched Ohuna",
    [200682] = "Vortex",
    [200684] = "Vortex",
    [200685] = "Vortex",
    [200686] = "Wildfire",
    [200688] = "Wildfire",
    [200689] = "Wildfire",
    [200690] = "Tremblor",
    [200692] = "Tremblor",
    [200693] = "Tremblor",
    [200694] = "Flow",
    [200696] = "Flow",
    [200697] = "Flow",
    [201004] = "Explorer Bezzert",
    [201802] = "Excavator Morgrum Emberflint",
    [201849] = "Adinakon",
    [201858] = "Lyver",
    [201878] = "Vikshi Thunderpaw",
    [201899] = "Izal Whitemoon",
    [202440] = "Enok the Stinky",
    [202452] = "Malfunctioning Matrix",
    [202458] = "Stargazer Zenoth",
    [204792] = "Shinmura",
    [204926] = "Delver Mardei",
    [204934] = "Trainer Orlogg",
    [222535] = "Haywire Servobot",
    [223406] = "Zaedu",
    [223407] = "Awakened Custodian",
    [223409] = "Guttergunk",
    [223442] = "Kyrie",
    [223444] = "Friendhaver Grem",
    [223446] = "Collector Dyna",
}
