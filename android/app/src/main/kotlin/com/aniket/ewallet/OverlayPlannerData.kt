package com.aniket.ewallet

import org.json.JSONArray
import org.json.JSONObject

/**
 * Money Planner sections + default subtypes (mirrors Flutter SmsSyncSheet).
 */
object OverlayPlannerData {
    val sections = listOf(
        "Essentials",
        "Investment",
        "Emergency Fund",
        "Goals",
        "Debt & EMI",
        "Personal",
        "Income",
    )

    private val defaultSubtypes = mapOf(
        "Essentials" to listOf(
            "Housing/Rent", "Electricity", "Internet/Phone", "Food & Groceries",
            "Transportation", "Healthcare", "Insurance", "Family responsibilities",
            "Other essential",
        ),
        "Investment" to listOf(
            "SIP", "Stocks", "Mutual funds", "Retirement", "Other investment",
        ),
        "Emergency Fund" to listOf(
            "Monthly contribution", "Top-up", "Other emergency",
        ),
        "Goals" to listOf(
            "Gold", "Furniture", "Vacation", "Laptop", "Bike",
            "House down payment", "Education", "Wedding", "Car", "Other goal",
        ),
        "Debt & EMI" to listOf(
            "Loan EMI", "Credit card", "Personal debt", "Other debt",
        ),
        "Personal" to listOf(
            "Entertainment", "Dining out", "Hobbies", "Shopping",
            "Lifestyle", "Other personal",
        ),
        "Income" to listOf(
            "Salary", "Other income", "Refund", "Transfer in",
        ),
    )

    fun defaultSectionForType(isCredit: Boolean): String =
        if (isCredit) "Income" else "Essentials"

    fun parseSubtypesFromJson(raw: String?): Map<String, List<String>> {
        val merged = mutableMapOf<String, MutableList<String>>()
        for ((section, defaults) in defaultSubtypes) {
            merged[section] = defaults.toMutableList()
        }
        if (raw.isNullOrBlank() || raw == "null") return merged.mapValues { it.value.toList() }

        try {
            val obj = JSONObject(raw)
            for (section in sections) {
                val arr = obj.optJSONArray(section) ?: continue
                val list = merged.getOrPut(section) { mutableListOf() }
                for (i in 0 until arr.length()) {
                    val name = arr.optString(i).trim()
                    if (name.isNotEmpty() && !list.contains(name)) {
                        list.add(0, name)
                    }
                }
            }
        } catch (_: Exception) {
        }
        return merged.mapValues { it.value.toList() }
    }

    fun subtypesForSection(section: String, subtypesMap: Map<String, List<String>>): List<String> {
        val list = subtypesMap[section] ?: defaultSubtypes[section] ?: listOf("Other")
        return if (list.isEmpty()) listOf("Other") else list
    }
}
