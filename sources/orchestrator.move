module rinoco::orchestrator {
    // === Imports ===

    use std::string::{Self, String};
    use sui::{
        // coin::Coin,
        coin::{Self, Coin},
        display::{Self},
        kiosk::{Self},
        package::{Self},
        sui::{SUI},
        // table_vec::{Self, TableVec},
        transfer_policy::{TransferPolicy},
        event
    };
    use rinoco::{
        // attributes::{Self},
        factory_settings::{FactorySetings},
        water_cooler::{Self, WaterCooler},
        rinoco::{Rinoco},
        warehouse::{Self, Warehouse},
        settings::{Self, Settings},
        // image::{Image},
    };

    // === Errors ===
    
    const ENotOwner: u64 = 0;
    const EInvalidPaymentAmount: u64 = 1;
    const EInvalidPhaseNumber: u64 = 2;
    const EInvalidPrice: u64 = 3;
    const EInvalidStatusNumber: u64 = 4;
    const EInvalidTicketForMintPhase: u64 = 5;
    const EMintNotLive: u64 = 6;
    const EMintWarehouseAlreadyInitialized: u64 = 7;
    const EMintWarehouseNotEmpty: u64 = 8;
    const EMintWarehouseNotInitialized: u64 = 9;
    // const EMizuNFTNotRevealed: u64 = 10;
    const EWarehouseIsEmpty: u64 = 11;
    const EWrongPhase: u64 = 12;
    // const ENFTNotFromCollection: u64 = 13;
    const ESettingsDoesNotMatchCooler: u64 = 14;
    const EWearhouseDoesNotMatchCooler: u64 = 15;
    const ENFTNotAllReaveled: u64 = 16;

    // === Constants ===

    const MINT_STATE_INACTIVE: u8 = 0;
    const MINT_STATE_ACTIVE: u8 = 1;

    // === Structs ===

    public struct ORCHESTRATOR has drop {}

    public struct WhitelistTicket has key {
        id: UID,
        waterCoolerId: ID,
        name: String,
        image_url: String,
        phase: u8,
    }

    public struct OriginalGangsterTicket has key {
        id: UID,
        waterCoolerId: ID,
        name: String,
        image_url: String,
        phase: u8,
    }

    // ====== Events ======

    public struct NFTMinted has copy, drop {
        nft_id: ID,
        kiosk_id: ID,
        minter: address,
    }

    // Orch Admin cap this can be used to make changes to the orch setting and warehouse
    public struct OrchAdminCap has key { id: UID, `for_settings`: ID, `for_warehouse`: ID}

    public struct OrchCap has key { id: UID, `for`: ID}


    // === Init Function ===

    fun init(
        otw: ORCHESTRATOR,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);


        let mut wl_ticket_display = display::new<WhitelistTicket>(&publisher, ctx);
        display::add(&mut wl_ticket_display, string::utf8(b"name"), string::utf8(b"{name} WL Ticket"));
        display::add(&mut wl_ticket_display, string::utf8(b"description"), string::utf8(b"{description}"));
        display::add(&mut wl_ticket_display, string::utf8(b"image_url"), string::utf8(b"{image_url}"));
        display::update_version(&mut wl_ticket_display);

        transfer::public_transfer(wl_ticket_display, ctx.sender());

        let mut og_ticket_display = display::new<OriginalGangsterTicket>(&publisher, ctx);
        display::add(&mut og_ticket_display, string::utf8(b"name"), string::utf8(b"{name} OG Ticket"));
        display::add(&mut og_ticket_display, string::utf8(b"description"), string::utf8(b"{description}"));
        display::add(&mut og_ticket_display, string::utf8(b"image_url"), string::utf8(b"{image_url}"));
        display::update_version(&mut og_ticket_display);


        transfer::public_transfer(og_ticket_display, ctx.sender());
        transfer::public_transfer(publisher, ctx.sender());
    }

     // === Public-view Functions ===

    public fun get_mintwarehouse_length(warehouse: &Warehouse) : u64 {
        warehouse.count()
    }

    // === Public-Mutative Functions ===


    public entry fun public_mint(
        waterCooler: &mut WaterCooler,
        factorySettings: &FactorySetings,
        warehouse: &mut Warehouse,
        settings: &Settings,
        policy: &TransferPolicy<Rinoco>,
        payment: Coin<SUI>,        
        ctx: &mut TxContext,
    ) {
        assert!(waterCooler.get_warehouse_id() == object::id(warehouse), EWearhouseDoesNotMatchCooler);
        assert!(waterCooler.get_settings_id() == object::id(settings), ESettingsDoesNotMatchCooler);
        assert!(warehouse.count() > 0, EWarehouseIsEmpty);
        assert!(settings.phase() == 3, EWrongPhase);
        assert!(settings.status() == MINT_STATE_ACTIVE, EMintNotLive);
        assert!(payment.value() == settings.price(), EInvalidPaymentAmount);

        mint_capsule(factorySettings, waterCooler, warehouse, policy, payment, ctx);
    }

    #[allow(unused_variable)]
    public fun whitelist_mint(
        ticket: WhitelistTicket,
        factorySettings: &FactorySetings,
        waterCooler: &mut WaterCooler,
        warehouse: &mut Warehouse,
        settings: &Settings,
        policy: &TransferPolicy<Rinoco>,
        payment: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        assert!(waterCooler.get_warehouse_id() == object::id(warehouse), EWearhouseDoesNotMatchCooler);
        assert!(waterCooler.get_settings_id() == object::id(settings), ESettingsDoesNotMatchCooler);

        let WhitelistTicket { id, name, image_url, waterCoolerId, phase } = ticket;
        
        assert!(settings.status() == MINT_STATE_ACTIVE, EMintNotLive);
        assert!(phase == settings.phase(), EInvalidTicketForMintPhase);
        assert!(waterCoolerId == object::id(waterCooler), EInvalidTicketForMintPhase);
        assert!(payment.value() == settings.price(), EInvalidPaymentAmount);


        mint_capsule(factorySettings, waterCooler, warehouse, policy, payment, ctx);
        id.delete();
    }

    #[allow(unused_variable)]
    public fun og_mint(
        ticket: OriginalGangsterTicket,
        factorySettings: &FactorySetings,
        waterCooler: &mut WaterCooler,
        warehouse: &mut Warehouse,
        settings: &Settings,
        policy: &TransferPolicy<Rinoco>,
        payment: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        assert!(waterCooler.get_warehouse_id() == object::id(warehouse), EWearhouseDoesNotMatchCooler);
        assert!(waterCooler.get_settings_id() == object::id(settings), ESettingsDoesNotMatchCooler);

        let OriginalGangsterTicket { id, name, image_url, waterCoolerId, phase } = ticket;
        
        assert!(settings.status() == MINT_STATE_ACTIVE, EMintNotLive);
        assert!(phase == settings.phase(), EInvalidTicketForMintPhase);
        assert!(waterCoolerId == object::id(waterCooler), EInvalidTicketForMintPhase);
        assert!(payment.value() == settings.price(), EInvalidPaymentAmount);

        mint_capsule(factorySettings, waterCooler, warehouse, policy, payment, ctx);
        id.delete();
    }

    // === Admin functions ===

    /// Add MizuNFTs to the mint warehouse.
    public fun stock_warehouse(
        cap: &OrchAdminCap,
        waterCooler: &WaterCooler,
        mut nfts: vector<Rinoco>,
        warehouse: &mut Warehouse,
    ) {
        assert!(waterCooler.get_is_initialized(), ENFTNotAllReaveled);        
        assert!(object::id(warehouse) == cap.`for_warehouse`, ENotOwner);        
       
       warehouse.stock(waterCooler.supply(), nfts);
    }

    /// Destroy an empty mint warehouse when it's no longer needed.
    public fun destroy_mint_warehouse(
        cap: &OrchAdminCap,
        warehouse: Warehouse,
    ) {
        assert!(warehouse.is_empty(), EMintWarehouseNotEmpty);
        assert!(warehouse.is_initialized() == true, EMintWarehouseNotInitialized);
        assert!(object::id(&warehouse) == cap.`for_warehouse`, ENotOwner);   

        warehouse.delete();
    }

    // Set mint price, status, phase
    public fun set_mint_price(
        cap: &OrchAdminCap,
        settings: &mut Settings,
        price: u64,
    ) {
        assert!(object::id(settings) == cap.`for_settings`, ENotOwner);        

        assert!(price >= 0, EInvalidPrice);
        settings.set_price(price);
    }

    public fun set_mint_status(
        cap: &OrchAdminCap,
        settings: &mut Settings,        
        status: u8,
    ) {
        assert!(object::id(settings) == cap.`for_settings`, ENotOwner);
        assert!(status == MINT_STATE_INACTIVE || status == MINT_STATE_ACTIVE, EInvalidStatusNumber);
        settings.set_status(status);
    }

    public fun set_mint_phase(
        cap: &OrchAdminCap,
        settings: &mut Settings,
        phase: u8,
    ) {
        assert!(object::id(settings) == cap.`for_settings`, ENotOwner);
        assert!(phase >= 1 && phase <= 3, EInvalidPhaseNumber);
        settings.set_phase(phase);
    }

    public fun create_og_ticket(
        _: &OrchAdminCap,
        waterCooler: &WaterCooler,
        owner: address,
        ctx: &mut TxContext
    ) {
        let og_ticket =  OriginalGangsterTicket {
            id: object::new(ctx),
            name: water_cooler::name(waterCooler),
            waterCoolerId: object::id(waterCooler),
            image_url: water_cooler::placeholder_image(waterCooler),
            phase: 1
        };

        transfer::transfer(og_ticket, owner);
    }

    public fun create_og_ticket_bulk(
        _: &OrchAdminCap,
        waterCooler: &WaterCooler,
        mut addresses: vector<address>,
        ctx: &mut TxContext
    ) {
        while(addresses.length() > 0) {
            let og_ticket =  OriginalGangsterTicket {
                id: object::new(ctx),
                name: water_cooler::name(waterCooler),
                waterCoolerId: object::id(waterCooler),
                image_url: water_cooler::placeholder_image(waterCooler),
                phase: 1
            };

            transfer::transfer(og_ticket, addresses.pop_back());
        }

    }

    public fun create_wl_ticket(
        _: &OrchAdminCap,
        waterCooler: &WaterCooler,
        owner: address,
        ctx: &mut TxContext
    ) {
        let whitelist_ticket =  WhitelistTicket {
            id: object::new(ctx),
            name: water_cooler::name(waterCooler),
            waterCoolerId: object::id(waterCooler),
            image_url: water_cooler::placeholder_image(waterCooler),
            phase: 2
        };

        transfer::transfer(whitelist_ticket, owner);
    }
    
    public fun create_wl_ticket_bulk(
        _: &OrchAdminCap,
        waterCooler: &WaterCooler,
        mut addresses: vector<address>,
        ctx: &mut TxContext
    ) {
        while(addresses.length() > 0) {
            let whitelist_ticket =  WhitelistTicket {
                id: object::new(ctx),
                name: water_cooler::name(waterCooler),
                waterCoolerId: object::id(waterCooler),
                image_url: water_cooler::placeholder_image(waterCooler),
                phase: 2
            };
            transfer::transfer(whitelist_ticket, addresses.pop_back());
        }
    }

    // === Package functions ===

    public(package) fun create_mint_distributer(ctx: &mut TxContext): (Settings, Warehouse) {
        let settings = settings::new(ctx);
        let warehouse = warehouse::new(ctx);

        // Here we transfer the mint admin cap to the person that bought the WaterCooler
        transfer::transfer(
            OrchAdminCap {
                id: object::new(ctx),
                `for_settings`: object::id(&settings),
                `for_warehouse`: object::id(&warehouse)
            },
             ctx.sender()
        );

        (settings, warehouse)
    }
    

    // === Private Functions ===

    #[allow(lint(self_transfer, share_owned))]
    fun mint_capsule(
        factorySettings: &FactorySetings,
        waterCooler: &mut WaterCooler,
        warehouse: &mut Warehouse,
        _policy: &TransferPolicy<Rinoco>,
        mut payment: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        // Safely unwrap the NFT from the warehouse
        let nft = warehouse.pop_nft(ctx);

        // Create a new kiosk and its owner capability
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(ctx);


        event::emit(NFTMinted { 
            nft_id: object::id(&nft),
            kiosk_id: object::id(&kiosk),
            minter: ctx.sender(),
        });

        // Place the NFT in the kiosk
        kiosk::place(&mut kiosk, &kiosk_owner_cap, nft);

        // Lock Rinoco into buyer's kiosk.
        // TO DO: Lock NFT in kiosk using NFT policy
        // kiosk::lock(&mut kiosk, &mut kiosk_owner_cap, policy, nft);

        // Transfer the kiosk owner capability to the sender
        transfer::public_transfer(kiosk_owner_cap, ctx.sender());

        // Share the kiosk object publicly
        transfer::public_share_object(kiosk);

        let coin_balance = payment.balance_mut();
        let profits = coin::take(coin_balance, factorySettings.get_mint_fee(), ctx);

        factorySettings.send_fees(profits);

        // Send the payment to the water cooler
        waterCooler.send_fees(payment);
        waterCooler.inc_minted();

        
        
    }


    // === Test Functions ===
    #[test_only]
    public fun init_for_mint(ctx: &mut TxContext) {
        init(ORCHESTRATOR {}, ctx);
    }
}
