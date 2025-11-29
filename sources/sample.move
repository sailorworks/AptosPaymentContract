module VoiceVault::payment_contract {
    use std::signer;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::account;

    struct PaymentEvents has key {
        payment_received: event::EventHandle<PaymentReceived>,
        royalty_paid: event::EventHandle<RoyaltyPaid>,
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

    public entry fun init(admin: &signer) {
        move_to(admin, PaymentEvents {
            payment_received: account::new_event_handle<PaymentReceived>(admin),
            royalty_paid: account::new_event_handle<RoyaltyPaid>(admin),
        });
    }

    public entry fun pay_and_split(
        payer: &signer,
        recipient: address,
        royalty_recipient: address,
        royalty_bps: u64,
        amount: u64
    ) acquires PaymentEvents {
        let payer_addr = signer::address_of(payer);

        let total_amount = amount;
        let royalty_amount = total_amount * royalty_bps / 10_000;
        let payout_amount = total_amount - royalty_amount;

        // Withdraw the total amount from payer
        let coins = coin::withdraw<AptosCoin>(payer, total_amount);
        
        // Extract royalty portion
        let royalty_coin = coin::extract(&mut coins, royalty_amount);
        
        // Deposit royalty to royalty recipient
        coin::deposit(royalty_recipient, royalty_coin);

        let events = borrow_global_mut<PaymentEvents>(payer_addr);
        event::emit_event(&mut events.royalty_paid, RoyaltyPaid {
            payer: payer_addr,
            royalty_recipient,
            amount: royalty_amount,
        });

        // Deposit remaining amount to recipient
        coin::deposit(recipient, coins);

        event::emit_event(&mut events.payment_received, PaymentReceived {
            from: payer_addr,
            to: recipient,
            amount: payout_amount,
        });
    }
}
