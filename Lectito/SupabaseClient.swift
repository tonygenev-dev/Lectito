//
//  SupabaseClient.swift
//  Lectito
//
//  Created by Tony on 09/04/2026.
//

import Foundation
import Supabase

// Replace these with your actual URL and Key from the Supabase dashboard
let supabaseURL = URL(string: "https://jkzvohmvolqfmmimlxaf.supabase.co")!
let supabaseKey = "sb_publishable_XTTF-NXEVHyt94pMoBbt9Q_RAUfPyQy"

let supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
