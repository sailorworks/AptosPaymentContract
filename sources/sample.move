module VoiceVault::payment_contract {
    use std::signer;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::account;

    struct PaymentEvents has key {
        payment_received: event::EventHandle<PaymentReceived>,
        royalty_paid: event::EventHandle<RoyaltyPaid>,
        platform_fee_paid: event::EventHandle<PlatformFeePaid>,
    }

    struct PaymentReceived has drop, store {
        from: address,
        to: address,
        amount: u64,
    }

    struct RoyaltyPaid has drop, store {
        payer: address,
        royalty_recipient: address,
        amount: u64,
    }

    struct PlatformFeePaid has drop, store {
        payer: address,
        platform: address,
        amount: u64,
    }

    public entry fun init(admin: &signer) {
        move_to(admin, PaymentEvents {
            payment_received: account::new_event_handle<PaymentReceived>(admin),
            royalty_paid: account::new_event_handle<RoyaltyPaid>(admin),
            platform_fee_paid: account::new_event_handle<PlatformFeePaid>(admin),
        });
    }

    // Payment with royalty split enabled: splits between platform, creator, and royalty recipient
    public entry fun pay_with_royalty_split(
        payer: &signer,
        creator: address,
        platform: address,
        royalty_recipient: address,
        amount: u64
    ) acquires PaymentEvents {
        let payer_addr = signer::address_of(payer);

        // Withdraw the total amount from payer
        let coins = coin::withdraw<AptosCoin>(payer, amount);
        
        // Fixed platform fee: 2.5% (250 basis points)
        let platform_fee = amount * 250 / 10_000;
        let remaining_after_platform = amount - platform_fee;
        
        // Fixed royalty: 10% (1000 basis points)
        let royalty_amount = remaining_after_platform * 1000 / 10_000;
        let creator_amount = remaining_after_platform - royalty_amount;

        // Extract and pay platform fee
        let platform_coin = coin::extract(&mut coins, platform_fee);
        coin::deposit(platform, platform_coin);

        // Extract and pay royalty
        let royalty_coin = coin::extract(&mut coins, royalty_amount);
        coin::deposit(royalty_recipient, royalty_coin);

        // Pay creator (remaining coins)
        coin::deposit(creator, coins);

        // Emit events
        let events = borrow_global_mut<PaymentEvents>(payer_addr);
        
        event::emit_event(&mut events.platform_fee_paid, PlatformFeePaid {
            payer: payer_addr,
            platform,
            amount: platform_fee,
        });

        event::emit_event(&mut events.royalty_paid, RoyaltyPaid {
            payer: payer_addr,
            royalty_recipient,
            amount: royalty_amount,
        });

        event::emit_event(&mut events.payment_received, PaymentReceived {
            from: payer_addr,
            to: creator,
            amount: creator_amount,
        });
    }

    // Payment without royalty split: full payment to creator (no platform fee, no royalty)
    public entry fun pay_full_to_creator(
        payer: &signer,
        creator: address,
        amount: u64
    ) acquires PaymentEvents {
        let payer_addr = signer::address_of(payer);

        // Withdraw and transfer full amount to creator
        let coins = coin::withdraw<AptosCoin>(payer, amount);
        coin::deposit(creator, coins);

        // Emit payment received event
        let events = borrow_global_mut<PaymentEvents>(payer_addr);
        event::emit_event(&mut events.payment_received, PaymentReceived {
            from: payer_addr,
            to: creator,
            amount,
        });
    }
}
