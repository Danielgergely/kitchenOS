//
//  SupabaseService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: Secrets.supabaseURL,
    supabaseKey: Secrets.supabasePublishableKey
)
