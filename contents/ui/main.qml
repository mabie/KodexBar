import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property var entries: []
    property string errorMessage: ""
    property string errorDetail: ""
    property string generatedAt: ""
    property bool loading: false
    property bool costLoading: false
    property string costErrorMessage: ""
    property var costSummaries: ({})
    property string codexbarCommand: Plasmoid.configuration.codexbarCommand || "codexbar"
    property string selectedProvider: Plasmoid.configuration.provider || "detect"
    property string selectedSource: Plasmoid.configuration.source || "detect"
    property string activeProvider: selectedProvider
    property string activeSource: selectedSource
    property var pendingCandidates: []
    property var failedCandidates: []
    property int selectedEntryIndex: 0
    property bool showCreditsInPanel: Plasmoid.configuration.showCreditsInPanel === undefined ? true : Plasmoid.configuration.showCreditsInPanel
    property bool showUsedPercentInPanel: Plasmoid.configuration.showUsedPercentInPanel === undefined ? true : Plasmoid.configuration.showUsedPercentInPanel
    property bool showProviderInPanel: Plasmoid.configuration.showProviderInPanel === undefined ? true : Plasmoid.configuration.showProviderInPanel
    property bool showEmailInWidget: Plasmoid.configuration.showEmailInWidget === undefined ? false : Plasmoid.configuration.showEmailInWidget
    property bool includeStatus: Plasmoid.configuration.includeStatus === undefined ? false : Plasmoid.configuration.includeStatus
    property bool showCostSummary: Plasmoid.configuration.showCostSummary === undefined ? true : Plasmoid.configuration.showCostSummary
    property bool hideUnavailableProviders: Plasmoid.configuration.hideUnavailableProviders === undefined ? true : Plasmoid.configuration.hideUnavailableProviders
    property int refreshSeconds: Math.max(10, Plasmoid.configuration.refreshInterval || 60)
    property string costHistoryMetric: "cost"
    property string currentTab: "limits"

    preferredRepresentation: compactRepresentation
    toolTipMainText: "KodexBar"
    toolTipSubText: {
        if (errorMessage.length > 0) {
            return errorMessage
        }
        if (entries.length > 0 && entries[0].signedOut) {
            return entries[0].errorMessage
        }
        return panelText()
    }

    function panelText() {
        if (entries.length === 0) {
            return loading ? i18n("Loading") : i18n("No data")
        }
        var first = null
        for (var i = 0; i < entries.length; i++) {
            if (!entries[i].errorMessage && entries[i].rows.length > 0) {
                first = entries[i]
                break
            }
        }
        if (first === null) {
            first = entries[0]
        }
        var parts = []
        if (showProviderInPanel) {
            parts.push(first.name || "Codex")
        }
        if (first.errorMessage) {
            parts.push(first.signedOut ? i18n("Sign in") : i18n("Error"))
            return parts.join(" ")
        }
        var displayedUsed = usedPercent(first.primaryPercentLeft)
        if (displayedUsed !== null && showUsedPercentInPanel) {
            parts.push(Math.round(displayedUsed) + "%")
        }
        if (first.creditsRemaining !== null && first.creditsRemaining !== undefined && showCreditsInPanel) {
            parts.push(formatCredits(first.creditsRemaining))
        }
        return parts.join(" ")
    }

    function formatNumber(value) {
        if (value === null || value === undefined || isNaN(value)) {
            return ""
        }
        if (Math.abs(value) >= 1000) {
            return Number(value).toLocaleString(Qt.locale(), "f", 0)
        }
        return Number(value).toLocaleString(Qt.locale(), "f", 1)
    }

    function formatCurrency(value, currencyCode) {
        if (value === null || value === undefined || isNaN(value)) {
            return ""
        }
        var prefix = currencyCode === "USD" ? "$" : ((currencyCode || "") + " ")
        return prefix + Number(value).toLocaleString(Qt.locale(), "f", 2)
    }

    function formatTokenCount(value) {
        if (value === null || value === undefined || isNaN(value)) {
            return ""
        }
        var absolute = Math.abs(Number(value))
        if (absolute >= 1000000000) {
            return Number(value / 1000000000).toLocaleString(Qt.locale(), "f", absolute >= 10000000000 ? 0 : 1) + "B"
        }
        if (absolute >= 1000000) {
            return Number(value / 1000000).toLocaleString(Qt.locale(), "f", absolute >= 10000000 ? 0 : 1) + "M"
        }
        if (absolute >= 1000) {
            return Number(value / 1000).toLocaleString(Qt.locale(), "f", absolute >= 10000 ? 0 : 1) + "K"
        }
        return Number(value).toLocaleString(Qt.locale(), "f", 0)
    }

    function localDayKey(date) {
        function pad(value) {
            return value < 10 ? "0" + value : String(value)
        }
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
    }

    function formatCredits(value) {
        if (value === null || value === undefined || isNaN(value)) {
            return ""
        }
        var formatted = Number(value).toLocaleString(Qt.locale(), "f", 2)
        var decimalPoint = Qt.locale().decimalPoint || "."
        while (formatted.indexOf(decimalPoint) !== -1 && formatted.endsWith("0")) {
            formatted = formatted.slice(0, -1)
        }
        if (formatted.endsWith(decimalPoint)) {
            formatted = formatted.slice(0, -decimalPoint.length)
        }
        return formatted
    }

    function usedPercent(percentLeft) {
        if (percentLeft === null || percentLeft === undefined || isNaN(percentLeft)) {
            return null
        }
        return Math.max(0, Math.min(100, 100 - percentLeft))
    }

    function formatUsedPercent(percentLeft, usageKnown) {
        if (usageKnown === false) {
            return i18n("Reset only")
        }
        var used = usedPercent(percentLeft)
        if (used === null) {
            return i18n("Unavailable")
        }
        return i18n("%1% used", Math.round(used))
    }

    function formatResetTime(value) {
        if (!value) {
            return ""
        }
        var reset = new Date(value)
        var timestamp = reset.getTime()
        if (isNaN(timestamp)) {
            return ""
        }
        var diff = Math.max(0, timestamp - Date.now())
        var minutes = Math.round(diff / 60000)
        if (minutes < 1) {
            return i18n("Resets now")
        }
        var hours = Math.floor(minutes / 60)
        var days = Math.floor(hours / 24)
        if (days > 0) {
            return i18n("Resets in %1d %2h", days, hours % 24)
        }
        if (hours > 0) {
            return i18n("Resets in %1h %2m", hours, minutes % 60)
        }
        return i18n("Resets in %1m", minutes)
    }

    function formatExpiryTime(value) {
        if (!value) {
            return ""
        }
        var expiry = new Date(value)
        var timestamp = expiry.getTime()
        if (isNaN(timestamp)) {
            return ""
        }
        var diff = Math.max(0, timestamp - Date.now())
        var minutes = Math.round(diff / 60000)
        if (minutes < 1) {
            return i18n("Expires now")
        }
        var hours = Math.floor(minutes / 60)
        var days = Math.floor(hours / 24)
        if (days > 0) {
            return i18n("Expires in %1d %2h", days, hours % 24)
        }
        if (hours > 0) {
            return i18n("Expires in %1h %2m", hours, minutes % 60)
        }
        return i18n("Expires in %1m", minutes)
    }

    function formatExpiryDate(value) {
        if (!value) {
            return ""
        }
        var expiry = new Date(value)
        if (isNaN(expiry.getTime())) {
            return String(value)
        }
        return Qt.formatDate(expiry, Locale.ShortFormat)
    }

    function resetTimeFromDescription(value) {
        if (!value) {
            return null
        }

        var text = String(value).trim()
        var direct = new Date(text)
        if (!isNaN(direct.getTime())) {
            return direct.toISOString()
        }

        var relative = /(\d+)\s*([dhm])\b/ig
        var match = null
        var minutes = 0
        while ((match = relative.exec(text)) !== null) {
            var amount = parseInt(match[1], 10)
            var unit = match[2].toLowerCase()
            if (unit === "d") {
                minutes += amount * 24 * 60
            } else if (unit === "h") {
                minutes += amount * 60
            } else {
                minutes += amount
            }
        }
        if (minutes > 0) {
            return new Date(Date.now() + minutes * 60000).toISOString()
        }

        var clock = text.match(/(?:resets?\s*)?(\d{1,2}):(\d{2})\s*(AM|PM)?/i)
        if (!clock) {
            return null
        }

        var hour = parseInt(clock[1], 10)
        var minute = parseInt(clock[2], 10)
        var meridiem = clock[3] ? clock[3].toUpperCase() : ""
        if (meridiem === "PM" && hour < 12) {
            hour += 12
        } else if (meridiem === "AM" && hour === 12) {
            hour = 0
        }

        var candidate = new Date()
        candidate.setHours(hour, minute, 0, 0)
        if (candidate.getTime() < Date.now()) {
            candidate.setDate(candidate.getDate() + 1)
        }
        return candidate.toISOString()
    }

    function commandLine(provider, source) {
        var command = shellQuote(codexbarCommand) + " usage --format json --json-only"
        if (provider && provider !== "detect") {
            command += " --provider " + shellQuote(provider)
        }
        if (source && source !== "detect") {
            command += " --source " + shellQuote(source)
        }
        if (includeStatus) {
            command += " --status"
        }
        return command
    }

    function costCommandLine() {
        var command = shellQuote(codexbarCommand) + " cost --format json --json-only --days 30"
        if (selectedProvider && selectedProvider !== "detect") {
            command += " --provider " + shellQuote(selectedProvider)
        }
        return command
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function refresh() {
        loading = true
        errorMessage = ""
        errorDetail = ""
        failedCandidates = []
        pendingCandidates = candidateList()
        executable.connectedSources = []
        refreshCost()
        tryNextCandidate()
    }

    function refreshCost() {
        costErrorMessage = ""
        if (!showCostSummary) {
            costLoading = false
            costSummaries = ({})
            applyCostSummaries()
            return
        }
        costLoading = true
        costExecutable.connectedSources = []
        costExecutable.connectSource(costCommandLine())
    }

    function candidateList() {
        var provider = selectedProvider || "detect"
        var source = selectedSource || "detect"
        var sources = source === "detect" || source === "auto" ? ["cli", "oauth", "api", "auto"] : [source]
        if (String(provider).toLowerCase() === "codex" && (source === "detect" || source === "auto")) {
            sources = ["oauth", "cli", "api", "auto"]
        }
        var result = []

        if (provider === "detect" && source === "detect") {
            // OAuth includes Codex reset credits; try it before the CLI's
            // default source when the widget is using automatic detection.
            result.push({ provider: "codex", source: "oauth" })
            result.push({ provider: "", source: "" })
        }

        if (provider !== "detect" && provider !== "all") {
            for (var i = 0; i < sources.length; i++) {
                result.push({ provider: provider, source: sources[i] })
            }
            return result
        }

        if (provider === "all" && source !== "detect") {
            return [{ provider: "all", source: source }]
        }

        return [
            { provider: "codex", source: "oauth" },
            { provider: "codex", source: "cli" },
            { provider: "codex", source: "api" },
            { provider: "claude", source: "cli" },
            { provider: "claude", source: "oauth" },
            { provider: "claude", source: "api" },
            { provider: "openai", source: "api" },
            { provider: "gemini", source: "api" },
            { provider: "copilot", source: "api" },
            { provider: "kilo", source: "cli" },
            { provider: "kilo", source: "api" },
            { provider: "kimi", source: "api" },
            { provider: "kimik2", source: "api" },
            { provider: "zai", source: "api" },
            { provider: "minimax", source: "api" },
            { provider: "kiro", source: "cli" },
            { provider: "vertexai", source: "oauth" },
            { provider: "warp", source: "api" },
            { provider: "openrouter", source: "api" },
            { provider: "elevenlabs", source: "api" },
            { provider: "ollama", source: "api" },
            { provider: "deepseek", source: "api" },
            { provider: "moonshot", source: "api" },
            { provider: "doubao", source: "api" },
            { provider: "codebuff", source: "api" },
            { provider: "crof", source: "api" },
            { provider: "venice", source: "api" },
            { provider: "bedrock", source: "api" },
            { provider: "groq", source: "api" },
            { provider: "llmproxy", source: "api" },
            { provider: "deepgram", source: "api" }
        ]
    }

    function tryNextCandidate() {
        if (pendingCandidates.length === 0) {
            loading = false
            entries = failedCandidates
            generatedAt = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
            if (entries.length === 0) {
                errorMessage = i18n("No usable CodexBar provider found")
                errorDetail = i18n("Configure a Linux-capable provider or choose a specific provider/source.")
            }
            return
        }

        var candidate = pendingCandidates.shift()
        activeProvider = candidate.provider
        activeSource = candidate.source
        executable.connectedSources = []
        executable.connectSource(commandLine(activeProvider, activeSource))
    }

    function hasUsableEntries(normalized) {
        for (var i = 0; i < normalized.length; i++) {
            if (!normalized[i].errorMessage
                    && ((normalized[i].rows && normalized[i].rows.length > 0)
                        || normalized[i].creditsRemaining !== null
                        || normalized[i].codeReviewRemainingPercent !== null)) {
                return true
            }
        }
        return false
    }

    function isUsableEntry(entry) {
        return entry && !entry.errorMessage
            && ((entry.rows && entry.rows.length > 0)
                || entry.creditsRemaining !== null && entry.creditsRemaining !== undefined
                || entry.codeReviewRemainingPercent !== null && entry.codeReviewRemainingPercent !== undefined)
    }

    function filterUnavailableEntries(normalized) {
        if (!hideUnavailableProviders) {
            return normalized
        }
        // Only filter the multi-provider view. Single-provider selection
        // must keep its error so the user sees why it failed.
        if (selectedProvider !== "all") {
            return normalized
        }
        if (!hasUsableEntries(normalized)) {
            return normalized
        }
        var kept = []
        for (var i = 0; i < normalized.length; i++) {
            if (isUsableEntry(normalized[i])) {
                kept.push(normalized[i])
            }
        }
        return kept.length > 0 ? kept : normalized
    }

    function selectedEntry() {
        if (!entries || entries.length === 0) {
            return null
        }
        var idx = Math.max(0, Math.min(selectedEntryIndex, entries.length - 1))
        return entries[idx]
    }

    function selectedEntries() {
        var entry = selectedEntry()
        return entry ? [entry] : []
    }

    function selectTab(name) {
        if (name !== "limits" && name !== "usage") {
            return
        }
        if (currentTab === name) {
            return
        }
        currentTab = name
        scrollToTop()
    }

    function scrollToTop() {
        // QQC2 ScrollView wraps content in a flickable; guard everything
        // so a missing internal API can never break tab switching.
        try {
            var flick = scrollView.contentItem
            if (flick && flick.contentY !== undefined) {
                flick.contentY = 0
            }
        } catch (e) {
        }
    }

    function appendFailedEntries(normalized) {
        var existing = failedCandidates
        for (var i = 0; i < normalized.length; i++) {
            if (normalized[i].errorMessage) {
                existing.push(normalized[i])
            }
        }
        failedCandidates = existing
    }

    function isCodexAuthenticationError(entry) {
        if (!entry || String(entry.provider || "").toLowerCase() !== "codex" || !entry.errorMessage) {
            return false
        }
        var message = String(entry.errorMessage).toLowerCase()
        return message.indexOf("authentication required") !== -1
            || message.indexOf("account authentication") !== -1
            || message.indexOf("not logged in") !== -1
            || message.indexOf("not signed in") !== -1
            || message.indexOf("login required") !== -1
            || message.indexOf("sign in required") !== -1
            || message.indexOf("signed out") !== -1
    }

    function stopForCodexAuthentication(normalized) {
        for (var i = 0; i < normalized.length; i++) {
            if (!isCodexAuthenticationError(normalized[i])) {
                continue
            }
            var entry = normalized[i]
            entry.signedOut = true
            entry.errorKind = "authentication"
            entry.errorMessage = i18n("Codex is installed, but the client is signed out. Run \"codex login\" in a terminal, then refresh.")
            loading = false
            errorMessage = ""
            errorDetail = ""
            generatedAt = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
            entries = [withCostSummary(entry)]
            return true
        }
        return false
    }

    function parsePayload(text) {
        if (!text || text.length === 0) {
            return {
                ok: false,
                error: i18n("No output from CodexBar CLI"),
                detail: ""
            }
        }
        try {
            var raw = JSON.parse(text)
            var rawEntries = raw instanceof Array ? raw : [raw]
            var normalized = []
            for (var i = 0; i < rawEntries.length; i++) {
                if (rawEntries[i] && typeof rawEntries[i] === "object") {
                    normalized.push(normalizeEntry(rawEntries[i]))
                }
            }
            return {
                ok: true,
                entries: normalized,
                usable: hasUsableEntries(normalized)
            }
        } catch (error) {
            return {
                ok: false,
                error: i18n("Invalid CodexBar CLI response"),
                detail: String(error)
            }
        }
    }

    function parseCostPayload(text) {
        if (!text || text.length === 0) {
            return {
                ok: false,
                error: i18n("No output from CodexBar cost")
            }
        }
        try {
            var raw = JSON.parse(text)
            var rawEntries = raw instanceof Array ? raw : [raw]
            var summaries = {}
            for (var i = 0; i < rawEntries.length; i++) {
                var summary = normalizeCostSummary(rawEntries[i])
                if (summary !== null) {
                    summaries[String(summary.provider).toLowerCase()] = summary
                }
            }
            return {
                ok: true,
                summaries: summaries
            }
        } catch (error) {
            return {
                ok: false,
                error: i18n("Invalid CodexBar cost response") + ": " + String(error)
            }
        }
    }

    function normalizeCostSummary(entry) {
        if (!entry || typeof entry !== "object" || !entry.provider) {
            return null
        }
        var todayCost = typeof entry.sessionCostUSD === "number" ? entry.sessionCostUSD : null
        var todayTokens = typeof entry.sessionTokens === "number" ? entry.sessionTokens : null
        var dayKey = localDayKey(new Date())
        var daily = entry.daily instanceof Array ? entry.daily : []
        var history = []
        var modelTotals = {}
        for (var i = 0; i < daily.length; i++) {
            var day = daily[i]
            if (!day || typeof day !== "object" || !day.date) {
                continue
            }
            var dayCost = typeof day.totalCost === "number" ? day.totalCost : 0
            var dayTokens = typeof day.totalTokens === "number" ? day.totalTokens : 0
            history.push({
                date: String(day.date),
                totalCost: dayCost,
                totalTokens: dayTokens
            })
            if (day.date === dayKey) {
                todayCost = dayCost
                todayTokens = dayTokens
            }
            var breakdowns = day.modelBreakdowns instanceof Array ? day.modelBreakdowns : []
            for (var m = 0; m < breakdowns.length; m++) {
                var breakdown = breakdowns[m]
                if (!breakdown || !breakdown.modelName) {
                    continue
                }
                var name = String(breakdown.modelName)
                var agg = modelTotals[name] || { modelName: name, totalCost: 0, totalTokens: 0 }
                if (typeof breakdown.cost === "number") {
                    agg.totalCost += breakdown.cost
                }
                if (typeof breakdown.totalTokens === "number") {
                    agg.totalTokens += breakdown.totalTokens
                }
                modelTotals[name] = agg
            }
        }
        history.sort(function(a, b) { return a.date < b.date ? -1 : (a.date > b.date ? 1 : 0) })
        var models = []
        var currencyForModels = entry.currencyCode || "USD"
        for (var key in modelTotals) {
            modelTotals[key].currencyCode = currencyForModels
            models.push(modelTotals[key])
        }
        models.sort(function(a, b) {
            if (b.totalCost !== a.totalCost) {
                return b.totalCost - a.totalCost
            }
            return b.totalTokens - a.totalTokens
        })
        var totalCost = typeof entry.last30DaysCostUSD === "number"
            ? entry.last30DaysCostUSD
            : (entry.totals && typeof entry.totals.totalCost === "number" ? entry.totals.totalCost : null)
        var totalTokens = typeof entry.last30DaysTokens === "number"
            ? entry.last30DaysTokens
            : (entry.totals && typeof entry.totals.totalTokens === "number" ? entry.totals.totalTokens : null)
        if (todayCost === null && todayTokens === null && totalCost === null && totalTokens === null) {
            return null
        }
        return {
            provider: entry.provider,
            source: entry.source || "",
            currencyCode: entry.currencyCode || "USD",
            historyDays: typeof entry.historyDays === "number" ? entry.historyDays : 30,
            todayCost: todayCost,
            todayTokens: todayTokens,
            totalCost: totalCost,
            totalTokens: totalTokens,
            daily: history,
            models: models.slice(0, 5),
            updatedAt: entry.updatedAt || ""
        }
    }

    function historySeries(summary, metric, days) {
        var count = Math.max(7, Math.min(90, days || 30))
        var byDate = {}
        var input = summary && summary.daily instanceof Array ? summary.daily : []
        for (var i = 0; i < input.length; i++) {
            if (input[i] && input[i].date) {
                byDate[input[i].date] = input[i]
            }
        }
        var series = []
        var today = new Date()
        today.setHours(0, 0, 0, 0)
        for (var d = count - 1; d >= 0; d--) {
            var date = new Date(today.getTime() - d * 86400000)
            var key = localDayKey(date)
            var found = byDate[key]
            var dayCost = found && typeof found.totalCost === "number" ? found.totalCost : 0
            var dayTokens = found && typeof found.totalTokens === "number" ? found.totalTokens : 0
            series.push({
                date: key,
                value: metric === "tokens" ? dayTokens : dayCost,
                totalCost: dayCost,
                totalTokens: dayTokens
            })
        }
        return series
    }

    function historyPeak(series) {
        var peak = 0
        for (var i = 0; i < series.length; i++) {
            if (series[i].value > peak) {
                peak = series[i].value
            }
        }
        return peak
    }

    function historyPeakDate(series) {
        var peak = historyPeak(series)
        if (!(peak > 0)) {
            return ""
        }
        for (var i = 0; i < series.length; i++) {
            if (series[i].value === peak) {
                return series[i].date
            }
        }
        return ""
    }

    function formatMonthDay(dateStr) {
        if (!dateStr || dateStr.length < 10) {
            return ""
        }
        var parts = dateStr.split("-")
        var date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
        // Drop the year from the locale's short date format.
        var format = Qt.locale().dateFormat(Locale.ShortFormat)
            .replace(/[yY]+/g, "")
            .replace(/^[^A-Za-z]+/, "")
            .replace(/[^A-Za-z]+$/, "")
        return Qt.locale().toString(date, format)
    }

    function formatTooltipDate(dateStr) {
        if (!dateStr || dateStr.length < 10) {
            return ""
        }
        var parts = dateStr.split("-")
        var date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
        var sameYear = date.getFullYear() === new Date().getFullYear()
        return Qt.locale().toString(date, sameYear ? "ddd, MMM d" : "ddd, MMM d yyyy")
    }

    function historyTooltipValues(item, metric, currencyCode) {
        if (!item) {
            return ""
        }
        var cost = typeof item.totalCost === "number" ? item.totalCost : 0
        var tokens = typeof item.totalTokens === "number" ? item.totalTokens : 0
        if (cost === 0 && tokens === 0) {
            return i18n("No usage")
        }
        var costText = formatCurrency(cost, currencyCode || "USD")
        var tokensText = i18n("%1 tokens", formatTokenCount(tokens))
        return metric === "tokens" ? tokensText + " - " + costText : costText + " - " + tokensText
    }

    function costSummaryRows(summary) {
        if (!summary) {
            return []
        }
        var rows = []
        if (summary.todayCost !== null || summary.todayTokens !== null) {
            rows.push({
                label: i18n("Today"),
                value: formatCostAndTokens(summary.todayCost, summary.todayTokens, summary.currencyCode)
            })
        }
        if (summary.totalCost !== null || summary.totalTokens !== null) {
            rows.push({
                label: i18np("Last day", "Last %1 days", summary.historyDays || 30),
                value: formatCostAndTokens(summary.totalCost, summary.totalTokens, summary.currencyCode)
            })
        }
        return rows
    }

    function formatCostAndTokens(cost, tokens, currencyCode) {
        var parts = []
        if (cost !== null && cost !== undefined && !isNaN(cost)) {
            parts.push(formatCurrency(cost, currencyCode || "USD"))
        }
        if (tokens !== null && tokens !== undefined && !isNaN(tokens)) {
            parts.push(i18n("%1 tokens", formatTokenCount(tokens)))
        }
        return parts.join(" - ")
    }

    function withCostSummary(entry) {
        if (!entry || typeof entry !== "object") {
            return entry
        }
        var key = String(entry.provider || "").toLowerCase()
        var copy = {}
        for (var prop in entry) {
            copy[prop] = entry[prop]
        }
        copy.costSummary = costSummaries[key] || null
        return copy
    }

    function applyCostSummaries() {
        if (!entries || entries.length === 0) {
            return
        }
        var updated = []
        for (var i = 0; i < entries.length; i++) {
            updated.push(withCostSummary(entries[i]))
        }
        entries = updated
    }

    function providerName(raw) {
        var key = String(raw || "").toLowerCase()
        var names = {
            "abacus": "Abacus AI",
            "alibaba": "Alibaba Coding Plan",
            "alibabatokenplan": "Alibaba Token Plan",
            "amp": "Amp",
            "antigravity": "Antigravity",
            "augment": "Augment",
            "bedrock": "AWS Bedrock",
            "codex": "Codex",
            "claude": "Claude",
            "openai": "OpenAI API",
            "azureopenai": "Azure OpenAI",
            "cursor": "Cursor",
            "opencode": "OpenCode",
            "opencodego": "OpenCode Go",
            "factory": "Droid",
            "devin": "Devin",
            "zai": "z.ai",
            "minimax": "MiniMax",
            "manus": "Manus",
            "kimi": "Kimi",
            "kiro": "Kiro",
            "vertexai": "Vertex AI",
            "jetbrains": "JetBrains AI",
            "kimik2": "Kimi K2",
            "moonshot": "Moonshot",
            "synthetic": "Synthetic",
            "t3chat": "T3 Chat",
            "warp": "Warp",
            "elevenlabs": "ElevenLabs",
            "windsurf": "Windsurf",
            "perplexity": "Perplexity",
            "mimo": "Xiaomi MiMo",
            "doubao": "Doubao",
            "mistral": "Mistral",
            "deepseek": "DeepSeek",
            "codebuff": "Codebuff",
            "crof": "Crof",
            "venice": "Venice",
            "commandcode": "Command Code",
            "stepfun": "StepFun",
            "grok": "Grok",
            "groq": "GroqCloud",
            "openrouter": "OpenRouter",
            "deepgram": "Deepgram",
            "llmproxy": "LLM Proxy",
            "copilot": "Copilot",
            "gemini": "Gemini",
            "kilo": "Kilo Code",
            "ollama": "Ollama"
        }
        return names[key] || (raw ? String(raw).charAt(0).toUpperCase() + String(raw).slice(1) : i18n("Provider"))
    }

    function providerIconSource(raw) {
        var key = String(raw || "").toLowerCase()
        var icons = {
            "abacus": "abacus",
            "alibaba": "alibaba",
            "alibabatokenplan": "alibabatokenplan",
            "amp": "amp",
            "antigravity": "antigravity",
            "augment": "augment",
            "bedrock": "bedrock",
            "codex": "codex",
            "claude": "claude",
            "openai": "openai",
            "azureopenai": "azureopenai",
            "cursor": "cursor",
            "opencode": "opencode",
            "opencodego": "opencodego",
            "factory": "factory",
            "devin": "devin",
            "zai": "zai",
            "minimax": "minimax",
            "manus": "manus",
            "kimi": "kimi",
            "kiro": "kiro",
            "vertexai": "vertexai",
            "jetbrains": "jetbrains",
            "kimik2": "kimik2",
            "moonshot": "moonshot",
            "synthetic": "synthetic",
            "t3chat": "t3chat",
            "warp": "warp",
            "elevenlabs": "elevenlabs",
            "windsurf": "windsurf",
            "perplexity": "perplexity",
            "mimo": "mimo",
            "doubao": "doubao",
            "mistral": "mistral",
            "deepseek": "deepseek",
            "codebuff": "codebuff",
            "crof": "crof",
            "venice": "venice",
            "commandcode": "commandcode",
            "stepfun": "stepfun",
            "grok": "grok",
            "groq": "groq",
            "openrouter": "openrouter",
            "deepgram": "deepgram",
            "llmproxy": "llmproxy",
            "copilot": "copilot",
            "gemini": "gemini",
            "kilo": "kilo",
            "ollama": "ollama"
        }
        return Qt.resolvedUrl("../icons/providers/" + (icons[key] || "codex") + ".svg")
    }

    function percentLeft(window) {
        if (!window || typeof window !== "object") {
            return null
        }
        if (typeof window.remainingPercent === "number") {
            return Math.max(0, Math.min(100, window.remainingPercent))
        }
        if (typeof window.usedPercent === "number") {
            return Math.max(0, Math.min(100, 100 - window.usedPercent))
        }
        return null
    }

    function displayPercentLeft(provider, primary, secondary) {
        var primaryLeft = percentLeft(primary)
        if (primaryLeft !== null || String(provider || "").toLowerCase() !== "codex") {
            return primaryLeft
        }

        return percentLeft(secondary)
    }

    function resetAt(window) {
        if (!window || typeof window !== "object") {
            return null
        }

        var fields = ["resetsAt", "resetAt", "resetTime", "resetDate"]
        for (var i = 0; i < fields.length; i++) {
            if (window[fields[i]]) {
                return window[fields[i]]
            }
        }

        if (typeof window.resetTimestamp === "number") {
            var timestamp = window.resetTimestamp < 10000000000
                ? window.resetTimestamp * 1000
                : window.resetTimestamp
            return new Date(timestamp).toISOString()
        }

        return resetTimeFromDescription(window.resetDescription || window.resetsIn || "")
    }

    function normalizeCodexResetCredits(raw) {
        if (!raw || typeof raw !== "object") {
            return null
        }

        var credits = raw.credits instanceof Array ? raw.credits : []
        var availableCredits = []
        var nextExpiresAt = null
        var now = Date.now()
        for (var i = 0; i < credits.length; i++) {
            var credit = credits[i]
            if (!credit || typeof credit !== "object"
                    || (credit.status && String(credit.status).toLowerCase() !== "available")) {
                continue
            }

            var expiresAt = credit.expires_at || credit.expiresAt || ""
            var expiry = expiresAt ? new Date(expiresAt) : null
            if (expiry && !isNaN(expiry.getTime()) && expiry.getTime() <= now) {
                continue
            }

            availableCredits.push(credit)
            if (expiry && !isNaN(expiry.getTime())
                    && (nextExpiresAt === null || expiry.getTime() < new Date(nextExpiresAt).getTime())) {
                nextExpiresAt = expiry.toISOString()
            }
        }

        var availableCount = typeof raw.availableCount === "number"
            ? Math.max(0, Math.round(raw.availableCount))
            : availableCredits.length
        if (typeof raw.availableCount !== "number" && credits.length === 0) {
            return null
        }

        var expirations = []
        for (var k = 0; k < availableCredits.length; k++) {
            var item = availableCredits[k]
            var itemExpiresAt = item ? (item.expires_at || item.expiresAt || "") : ""
            if (!itemExpiresAt) {
                continue
            }
            var itemExpiry = new Date(itemExpiresAt)
            if (isNaN(itemExpiry.getTime())) {
                continue
            }
            expirations.push(itemExpiry.toISOString())
        }
        expirations.sort(function(a, b) { return new Date(a).getTime() - new Date(b).getTime() })

        return {
            availableCount: availableCount,
            nextExpiresAt: nextExpiresAt,
            expirations: expirations,
            updatedAt: raw.updatedAt || ""
        }
    }

    function windowDetail(window, usageKnown) {
        if (!window || typeof window !== "object") {
            return ""
        }
        var parts = []
        if (usageKnown === false) {
            parts.push(i18n("Usage not reported"))
        }
        if (window.resetDescription) {
            parts.push(window.resetDescription)
        }
        if (typeof window.nextRegenPercent === "number" && window.nextRegenPercent > 0) {
            parts.push(i18n("+%1% next regen", Math.round(window.nextRegenPercent)))
        }
        return parts.join(" - ")
    }

    function providerCostRow(cost) {
        if (!cost || typeof cost !== "object" || typeof cost.used !== "number" || typeof cost.limit !== "number" || cost.limit <= 0) {
            return null
        }
        var used = Math.max(0, Math.min(100, cost.used / cost.limit * 100))
        var detail = formatCurrency(cost.used, cost.currencyCode) + " / " + formatCurrency(cost.limit, cost.currencyCode)
        if (typeof cost.nextRegenAmount === "number" && cost.nextRegenAmount > 0) {
            detail += " - " + i18n("+%1 next regen", formatNumber(cost.nextRegenAmount))
        }
        return {
            title: cost.period || i18n("Spend"),
            percentLeft: Math.max(0, 100 - used),
            resetsAt: cost.resetsAt || null,
            detail: detail,
            usageKnown: true
        }
    }

    function dashboardSummary(dashboard) {
        if (!dashboard || typeof dashboard !== "object") {
            return []
        }
        var summary = []
        if (typeof dashboard.codeReviewRemainingPercent === "number") {
            summary.push(i18n("Code review: %1% remaining", Math.round(dashboard.codeReviewRemainingPercent)))
        }
        if (dashboard.accountPlan) {
            summary.push(i18n("Plan: %1", dashboard.accountPlan))
        }
        if (dashboard.creditEvents && dashboard.creditEvents.length > 0) {
            summary.push(i18np("%1 credit event", "%1 credit events", dashboard.creditEvents.length))
        }
        if (dashboard.dailyBreakdown && dashboard.dailyBreakdown.length > 0) {
            summary.push(i18np("%1 credit-history day", "%1 credit-history days", dashboard.dailyBreakdown.length))
        }
        if (dashboard.usageBreakdown && dashboard.usageBreakdown.length > 0) {
            summary.push(i18np("%1 usage-breakdown day", "%1 usage-breakdown days", dashboard.usageBreakdown.length))
        }
        return summary
    }

    function normalizeEntry(entry) {
        var usage = entry.usage && typeof entry.usage === "object" ? entry.usage : {}
        var identity = usage.identity && typeof usage.identity === "object" ? usage.identity : {}
        var credits = entry.credits && typeof entry.credits === "object" ? entry.credits : null
        var dashboard = entry.openaiDashboard && typeof entry.openaiDashboard === "object" ? entry.openaiDashboard : {}
        var error = entry.error && typeof entry.error === "object" ? entry.error : null
        var primary = usage.primary
        var secondary = usage.secondary
        var tertiary = usage.tertiary
        var providerCost = usage.providerCost && typeof usage.providerCost === "object" ? usage.providerCost : null
        var status = entry.status && typeof entry.status === "object" ? entry.status : null
        var codexResetCredits = String(entry.provider || "").toLowerCase() === "codex"
            ? normalizeCodexResetCredits(usage.codexResetCredits || entry.codexResetCredits)
            : null
        var rows = []
        var windows = [
            { title: i18n("Session"), data: primary },
            { title: i18n("Weekly"), data: secondary },
            { title: i18n("Extra"), data: tertiary }
        ]
        for (var i = 0; i < windows.length; i++) {
            var left = percentLeft(windows[i].data)
            if (left !== null) {
                rows.push({
                    title: windows[i].title,
                    percentLeft: left,
                    resetsAt: resetAt(windows[i].data),
                    detail: windowDetail(windows[i].data, true),
                    usageKnown: true
                })
            }
        }
        var extraRateWindows = usage.extraRateWindows && usage.extraRateWindows.length ? usage.extraRateWindows : []
        for (var j = 0; j < extraRateWindows.length; j++) {
            var extra = extraRateWindows[j]
            if (!extra || !extra.window) {
                continue
            }
            var extraLeft = percentLeft(extra.window)
            if (extraLeft !== null || resetAt(extra.window)) {
                rows.push({
                    title: extra.title || i18n("Extra"),
                    percentLeft: extra.usageKnown === false ? null : extraLeft,
                    resetsAt: resetAt(extra.window),
                    detail: windowDetail(extra.window, extra.usageKnown),
                    usageKnown: extra.usageKnown !== false
                })
            }
        }
        var costRow = providerCostRow(providerCost)
        if (costRow !== null) {
            rows.push(costRow)
        }
        return {
            provider: entry.provider,
            name: providerName(entry.provider),
            version: entry.version,
            source: entry.source,
            account: entry.account || usage.accountEmail || identity.accountEmail || "",
            plan: usage.loginMethod || identity.loginMethod || dashboard.accountPlan || "",
            primaryPercentLeft: displayPercentLeft(entry.provider, primary, secondary),
            primaryResetsAt: resetAt(primary),
            secondaryPercentLeft: percentLeft(secondary),
            secondaryResetsAt: resetAt(secondary),
            codexResetCredits: codexResetCredits,
            creditsRemaining: credits ? credits.remaining : (typeof dashboard.creditsRemaining === "number" ? dashboard.creditsRemaining : null),
            codeReviewRemainingPercent: typeof dashboard.codeReviewRemainingPercent === "number" ? dashboard.codeReviewRemainingPercent : null,
            dashboardSummary: dashboardSummary(dashboard),
            rows: rows,
            updatedAt: usage.updatedAt || entry.updatedAt || "",
            status: entry.status,
            statusIndicator: status ? (status.indicator || "unknown") : "",
            statusDescription: status ? (status.description || "") : "",
            statusURL: status ? (status.url || "") : "",
            errorMessage: error ? (error.message || i18n("Provider returned an error")) : "",
            errorKind: error ? (error.kind || "") : "",
            signedOut: false
        }
    }

    function barColor(value) {
        if (value === null || value === undefined || isNaN(value)) {
            return Kirigami.Theme.disabledTextColor
        }
        if (value < 15) {
            return Kirigami.Theme.negativeTextColor
        }
        if (value < 35) {
            return Kirigami.Theme.neutralTextColor
        }
        return Kirigami.Theme.positiveTextColor
    }

    function usageAccent(percentLeft) {
        if (percentLeft === null || percentLeft === undefined || isNaN(percentLeft)) {
            return Kirigami.Theme.disabledTextColor
        }
        if (percentLeft < 15) {
            return Kirigami.Theme.negativeTextColor
        }
        if (percentLeft < 35) {
            return Kirigami.Theme.neutralTextColor
        }
        return Kirigami.Theme.highlightColor
    }

    function usedValue(percentLeft) {
        var u = usedPercent(percentLeft)
        if (u === null || u === undefined || isNaN(u)) {
            return null
        }
        return u
    }

    function blendColors(c1, c2, t) {
        t = Math.max(0, Math.min(1, t))
        return Qt.rgba(c1.r * (1 - t) + c2.r * t,
                       c1.g * (1 - t) + c2.g * t,
                       c1.b * (1 - t) + c2.b * t, 1)
    }

    function usageSeverityColor(used) {
        if (used === null || used === undefined || isNaN(used)) {
            return Kirigami.Theme.disabledTextColor
        }
        if (used < 50) {
            return Kirigami.Theme.positiveTextColor
        }
        if (used < 75) {
            return Kirigami.Theme.neutralTextColor
        }
        if (used < 90) {
            return blendColors(Kirigami.Theme.neutralTextColor, Kirigami.Theme.negativeTextColor, 0.55)
        }
        if (used < 97) {
            return Kirigami.Theme.negativeTextColor
        }
        return Qt.darker(Kirigami.Theme.negativeTextColor, 1.3)
    }

    function statusText(indicator, description) {
        if (!indicator) {
            return ""
        }
        var labels = {
            "none": i18n("Operational"),
            "minor": i18n("Partial outage"),
            "major": i18n("Major outage"),
            "critical": i18n("Critical issue"),
            "maintenance": i18n("Maintenance"),
            "unknown": i18n("Status unknown")
        }
        var label = labels[indicator] || indicator
        return description ? label + ": " + description : label
    }

    function statusColor(indicator) {
        if (indicator === "none") {
            return Kirigami.Theme.positiveTextColor
        }
        if (indicator === "minor" || indicator === "maintenance") {
            return Kirigami.Theme.neutralTextColor
        }
        if (indicator === "major" || indicator === "critical") {
            return Kirigami.Theme.negativeTextColor
        }
        return Kirigami.Theme.disabledTextColor
    }

    compactRepresentation: MouseArea {
        id: compact
        Layout.minimumWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.smallMedium
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.providerIconSource(root.entries.length > 0 ? root.entries[0].provider : "codex")
                isMask: true
                color: Kirigami.Theme.textColor
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }

            PlasmaComponents.Label {
                text: root.panelText()
                visible: text.length > 0
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 8
            }
        }
    }

    fullRepresentation: Item {
        id: full
        readonly property int popupMargin: Kirigami.Units.largeSpacing * 2
        readonly property int maxPopupHeight: Kirigami.Units.gridUnit * 44

        Layout.minimumWidth: Kirigami.Units.gridUnit * 30
        Layout.minimumHeight: Math.min(Layout.preferredHeight, maxPopupHeight)
        Layout.preferredWidth: Kirigami.Units.gridUnit * 34
        Layout.preferredHeight: Math.min(content.implicitHeight + popupMargin * 2, maxPopupHeight)

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: full.popupMargin
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.smallSpacing

                Item {
                    id: chipStrip
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    implicitWidth: chips.implicitWidth
                    implicitHeight: chips.implicitHeight

                    RowLayout {
                        id: chips
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: implicitWidth
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            id: chipRepeater
                            model: root.entries.length > 0 ? root.entries : [{ name: "KodexBar", provider: "kodexbar", primaryPercentLeft: null }]

                            delegate: Rectangle {
                                readonly property bool isSelected: index === root.selectedEntryIndex
                                readonly property color severity5: root.usageSeverityColor(root.usedValue(modelData.primaryPercentLeft))
                                readonly property color severityWeekly: root.usageSeverityColor(root.usedValue(modelData.secondaryPercentLeft))
                                Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 4.25, chipLabel.implicitWidth + Kirigami.Units.largeSpacing * 2)
                                Layout.preferredHeight: chipContent.implicitHeight + Kirigami.Units.smallSpacing * 2
                                radius: Kirigami.Units.cornerRadius
                                color: "transparent"
                                opacity: modelData.errorMessage ? 0.62 : 1
                                onSeverity5Changed: ringCanvas.requestPaint()
                                onSeverityWeeklyChanged: ringCanvas.requestPaint()

                                ColumnLayout {
                                    id: chipContent
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing / 2

                                    Item {
                                        readonly property int ringStroke: 4
                                        readonly property real ringGapAngle: 0.26
                                        readonly property int ringPad: 3
                                        readonly property int iconPx: Kirigami.Units.iconSizes.medium
                                        // One shared radius for both semicircles. They stay
                                        // separated through the angular gap at 3 and 9 o'clock.
                                        readonly property real rRing: iconPx / 2 + 8 + ringStroke / 2
                                        implicitWidth: (rRing + ringStroke / 2 + ringPad) * 2
                                        implicitHeight: (rRing + ringStroke / 2 + ringPad) * 2
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: implicitWidth
                                        Layout.preferredHeight: implicitHeight

                                        Canvas {
                                            id: ringCanvas
                                            anchors.fill: parent
                                            renderTarget: Canvas.FramebufferObject
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                var cx = width / 2
                                                var cy = height / 2
                                                var gap = parent.ringGapAngle
                                                var span = Math.PI - 2 * gap
                                                var track = Qt.rgba(Kirigami.Theme.disabledTextColor.r,
                                                                    Kirigami.Theme.disabledTextColor.g,
                                                                    Kirigami.Theme.disabledTextColor.b, 0.3)
                                                function strokeArc(from, to, color, ccw) {
                                                    ctx.beginPath()
                                                    ctx.arc(cx, cy, parent.rRing, from, to, !!ccw)
                                                    ctx.lineWidth = parent.ringStroke
                                                    ctx.strokeStyle = color
                                                    ctx.lineCap = "round"
                                                    ctx.stroke()
                                                }
                                                // Upper semicircle: 5-hour limit, lower: weekly limit.
                                                // Canvas angles run clockwise from 3 o'clock.
                                                // Both fills run left to right: upper starts at
                                                // 9 o'clock going over the top, lower starts at
                                                // 9 o'clock going counterclockwise along the bottom.
                                                strokeArc(Math.PI + gap, 2 * Math.PI - gap, track)
                                                var u5 = root.usedValue(modelData.primaryPercentLeft)
                                                if (u5 !== null && u5 > 0) {
                                                    strokeArc(Math.PI + gap, Math.PI + gap + Math.min(100, u5) / 100 * span, severity5)
                                                }
                                                strokeArc(gap, Math.PI - gap, track)
                                                var uw = root.usedValue(modelData.secondaryPercentLeft)
                                                if (uw !== null && uw > 0) {
                                                    strokeArc(Math.PI - gap, Math.PI - gap - Math.min(100, uw) / 100 * span, severityWeekly, true)
                                                }
                                            }
                                        }

                                        Kirigami.Icon {
                                            source: root.providerIconSource(modelData.provider)
                                            isMask: true
                                            color: Kirigami.Theme.textColor
                                            implicitWidth: Kirigami.Units.iconSizes.medium
                                            implicitHeight: Kirigami.Units.iconSizes.medium
                                            anchors.centerIn: parent
                                        }
                                    }

                                    PlasmaComponents.Label {
                                        id: chipLabel
                                        text: modelData.name || modelData.provider
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                                        color: Kirigami.Theme.textColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.selectedEntryIndex = index
                                        root.scrollToTop()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: chipSelection
                        readonly property var target: {
                            // Touch entries so the binding refreshes when the model is rebuilt.
                            var entryList = root.entries
                            var chipCount = chipRepeater.count
                            if (chipCount === 0) {
                                return null
                            }
                            return chipRepeater.itemAt(Math.max(0, Math.min(root.selectedEntryIndex, chipCount - 1)))
                        }
                        visible: target !== null
                        x: target ? target.x : 0
                        y: target ? target.y : 0
                        width: target ? target.width : 0
                        height: target ? target.height : 0
                        opacity: target ? target.opacity : 1
                        radius: Kirigami.Units.cornerRadius
                        color: "transparent"
                        border.width: 1
                        border.color: Kirigami.Theme.highlightColor

                        Behavior on x {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                        Behavior on width {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                        Behavior on height {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                    }
                }

                QQC2.ToolButton {
                    icon.name: "view-refresh"
                    display: QQC2.AbstractButton.IconOnly
                    enabled: !root.loading
                    text: i18n("Refresh")
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.refresh()
                }
            }

            PlasmaComponents.Label {
                visible: root.errorMessage.length > 0
                text: root.errorDetail.length > 0 ? root.errorMessage + "\n" + root.errorDetail : root.errorMessage
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: root.errorMessage.length === 0 && root.entries.length === 0
                text: root.loading ? i18n("Loading usage...") : i18n("No usage data available")
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            QQC2.ScrollView {
                id: scrollView
                visible: root.entries.length > 0
                clip: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: Math.min(contentList.implicitHeight, Kirigami.Units.gridUnit * 32)
                Layout.fillHeight: contentList.implicitHeight > Kirigami.Units.gridUnit * 32

                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                QQC2.ScrollBar.vertical.policy: contentList.implicitHeight > scrollView.height
                    ? QQC2.ScrollBar.AsNeeded
                    : QQC2.ScrollBar.AlwaysOff

                ColumnLayout {
                    id: contentList
                    width: scrollView.availableWidth
                    spacing: Kirigami.Units.largeSpacing

                    Repeater {
                        model: root.selectedEntries()

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            RowLayout {
                                Layout.fillWidth: true

                                ColumnLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Layout.fillWidth: true

                                    Kirigami.Heading {
                                        text: modelData.name || modelData.provider
                                        level: 2
                                        Layout.fillWidth: true
                                    }

                                    PlasmaComponents.Label {
                                        text: root.generatedAt.length > 0 ? i18n("Updated %1", root.generatedAt) : ""
                                        color: Kirigami.Theme.disabledTextColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                PlasmaComponents.Label {
                                    text: modelData.source || ""
                                    color: Kirigami.Theme.disabledTextColor
                                    visible: text.length > 0
                                    Layout.alignment: Qt.AlignBottom
                                }
                            }

                            PlasmaComponents.Label {
                                visible: modelData.statusIndicator && modelData.statusIndicator.length > 0
                                text: root.statusText(modelData.statusIndicator, modelData.statusDescription)
                                color: root.statusColor(modelData.statusIndicator)
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Kirigami.Separator {
                                Layout.fillWidth: true
                                Layout.topMargin: Kirigami.Units.smallSpacing
                                Layout.bottomMargin: Kirigami.Units.smallSpacing
                            }

                            Repeater {
                                model: modelData.rows || []

                                delegate: ColumnLayout {
                                    visible: root.currentTab === "limits"
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Kirigami.Units.smallSpacing

                                        Kirigami.Heading {
                                            text: modelData.title
                                            level: 4
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        PlasmaComponents.Label {
                                            text: root.formatResetTime(modelData.resetsAt)
                                            color: Kirigami.Theme.disabledTextColor
                                            visible: text.length > 0
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: Kirigami.Units.gridUnit * 9
                                        }

                                        PlasmaComponents.Label {
                                            text: root.formatUsedPercent(modelData.percentLeft, modelData.usageKnown)
                                            color: root.usageAccent(modelData.percentLeft)
                                        }
                                    }

                                    Rectangle {
                                        readonly property real used: root.usedPercent(modelData.percentLeft) || 0
                                        visible: modelData.usageKnown !== false
                                            && modelData.percentLeft !== null
                                            && modelData.percentLeft !== undefined
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 8
                                        radius: height / 2
                                        color: Qt.rgba(Kirigami.Theme.disabledTextColor.r, Kirigami.Theme.disabledTextColor.g, Kirigami.Theme.disabledTextColor.b, 0.24)
                                        clip: true

                                        Rectangle {
                                            width: Math.max(parent.height, parent.width * parent.used / 100)
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.usageAccent(modelData.percentLeft)
                                        }
                                    }

                                    PlasmaComponents.Label {
                                        visible: modelData.detail && modelData.detail.length > 0
                                        text: modelData.detail || ""
                                        color: Kirigami.Theme.disabledTextColor
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            ColumnLayout {
                                id: resetBlock
                                property bool expanded: false
                                Layout.fillWidth: true
                                visible: root.currentTab === "limits"
                                    && modelData.codexResetCredits !== null
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Heading {
                                    text: i18n("Rate-limit resets")
                                    level: 4
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: availableRow.implicitHeight

                                    RowLayout {
                                        id: availableRow
                                        anchors.fill: parent
                                        spacing: Kirigami.Units.smallSpacing

                                        PlasmaComponents.Label {
                                            text: i18n("Available")
                                            Layout.fillWidth: true
                                        }

                                        PlasmaComponents.Label {
                                            text: i18np("%1 reset", "%1 resets", modelData.codexResetCredits
                                                ? modelData.codexResetCredits.availableCount : 0)
                                            color: Kirigami.Theme.disabledTextColor
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Kirigami.Icon {
                                            source: "arrow-down"
                                            isMask: true
                                            implicitWidth: Kirigami.Units.iconSizes.small
                                            implicitHeight: Kirigami.Units.iconSizes.small
                                            color: Kirigami.Theme.disabledTextColor
                                            Layout.alignment: Qt.AlignVCenter
                                            rotation: resetBlock.expanded ? 180 : 0
                                            Behavior on rotation {
                                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: resetBlock.expanded = !resetBlock.expanded
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing
                                    visible: !resetBlock.expanded
                                        && modelData.codexResetCredits
                                        && modelData.codexResetCredits.nextExpiresAt
                                        && modelData.codexResetCredits.nextExpiresAt.length > 0

                                    PlasmaComponents.Label {
                                        text: i18n("Next expiry")
                                        Layout.fillWidth: true
                                    }

                                    PlasmaComponents.Label {
                                        text: root.formatExpiryTime(modelData.codexResetCredits
                                            ? modelData.codexResetCredits.nextExpiresAt : "")
                                        color: Kirigami.Theme.disabledTextColor
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                Item {
                                    id: resetsExpander
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: resetBlock.expanded ? expirationsColumn.implicitHeight : 0
                                    Behavior on Layout.preferredHeight {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                    clip: true
                                    opacity: resetBlock.expanded ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                    visible: modelData.codexResetCredits
                                        && ((modelData.codexResetCredits.expirations
                                            && modelData.codexResetCredits.expirations.length > 0)
                                            || (modelData.codexResetCredits.nextExpiresAt
                                                && modelData.codexResetCredits.nextExpiresAt.length > 0))

                                    ColumnLayout {
                                        id: expirationsColumn
                                        width: parent.width
                                        spacing: Kirigami.Units.smallSpacing

                                        Repeater {
                                            model: {
                                                var credits = modelData.codexResetCredits
                                                if (!credits) {
                                                    return []
                                                }
                                                if (credits.expirations && credits.expirations.length > 0) {
                                                    return credits.expirations
                                                }
                                                if (credits.nextExpiresAt && credits.nextExpiresAt.length > 0) {
                                                    return [credits.nextExpiresAt]
                                                }
                                                return []
                                            }

                                            delegate: RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Kirigami.Units.smallSpacing

                                                PlasmaComponents.Label {
                                                    text: root.formatExpiryDate(modelData)
                                                    color: Kirigami.Theme.disabledTextColor
                                                    Layout.fillWidth: true
                                                    Layout.leftMargin: Kirigami.Units.largeSpacing
                                                    elide: Text.ElideRight
                                                }

                                                PlasmaComponents.Label {
                                                    text: root.formatExpiryTime(modelData)
                                                    color: Kirigami.Theme.disabledTextColor
                                                    horizontalAlignment: Text.AlignRight
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            PlasmaComponents.Label {
                                visible: modelData.errorMessage && modelData.errorMessage.length > 0
                                text: modelData.errorKind && modelData.errorKind.length > 0 && !modelData.signedOut
                                    ? modelData.errorKind + ": " + modelData.errorMessage
                                    : modelData.errorMessage
                                color: Kirigami.Theme.negativeTextColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.currentTab === "usage"
                                    && root.showCostSummary
                                    && modelData.costSummary
                                    && root.costSummaryRows(modelData.costSummary).length > 0
                                spacing: Kirigami.Units.smallSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    Kirigami.Heading {
                                        text: i18n("Cost")
                                        level: 4
                                        Layout.fillWidth: true
                                    }

                                    QQC2.ToolButton {
                                        text: i18n("Cost")
                                        checkable: true
                                        checked: root.costHistoryMetric === "cost"
                                        onClicked: root.costHistoryMetric = "cost"
                                    }

                                    QQC2.ToolButton {
                                        text: i18n("Tokens")
                                        checkable: true
                                        checked: root.costHistoryMetric === "tokens"
                                        onClicked: root.costHistoryMetric = "tokens"
                                    }
                                }

                                Repeater {
                                    model: root.costSummaryRows(modelData.costSummary)

                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Kirigami.Units.smallSpacing

                                        PlasmaComponents.Label {
                                            text: modelData.label
                                            color: Kirigami.Theme.textColor
                                            Layout.fillWidth: true
                                        }

                                        PlasmaComponents.Label {
                                            text: modelData.value
                                            color: Kirigami.Theme.disabledTextColor
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                                        }
                                    }
                                }

                                Item {
                                    id: historyChart
                                    visible: modelData.costSummary
                                        && modelData.costSummary.daily
                                        && modelData.costSummary.daily.length > 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 6

                                    function startReveal() {
                                        revealAnimation.restart()
                                    }

                                    Connections {
                                        target: root

                                        function onExpandedChanged() {
                                            if (root.expanded && root.currentTab === "usage") {
                                                historyChart.startReveal()
                                            }
                                        }

                                        function onCurrentTabChanged() {
                                            if (root.expanded && root.currentTab === "usage") {
                                                historyChart.startReveal()
                                            }
                                        }

                                        function onCostHistoryMetricChanged() {
                                            historyChart.startReveal()
                                        }
                                    }

                                    NumberAnimation {
                                        id: revealAnimation
                                        target: historyCanvas
                                        property: "revealProgress"
                                        from: 0
                                        to: 1
                                        duration: 900
                                        easing.type: Easing.OutCubic
                                    }

                                    Canvas {
                                        id: historyCanvas
                                        anchors.fill: parent
                                        renderTarget: Canvas.FramebufferObject
                                        property var series: root.historySeries(
                                            modelData.costSummary,
                                            root.costHistoryMetric,
                                            modelData.costSummary ? modelData.costSummary.historyDays : 30)
                                        property real peak: root.historyPeak(series)
                                        property int hoveredIndex: -1
                                        property real revealProgress: 1
                                        onSeriesChanged: requestPaint()
                                        onPeakChanged: requestPaint()
                                        onHoveredIndexChanged: requestPaint()
                                        onRevealProgressChanged: requestPaint()
                                        Component.onCompleted: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            if (!series || series.length === 0) {
                                                return
                                            }
                                            var track = Qt.rgba(Kirigami.Theme.disabledTextColor.r,
                                                                Kirigami.Theme.disabledTextColor.g,
                                                                Kirigami.Theme.disabledTextColor.b, 0.22)
                                            var fill = Kirigami.Theme.highlightColor
                                            var hoverFill = Qt.lighter(fill, 1.35)
                                            var n = series.length
                                            var slot = width / n
                                            var barW = Math.max(2, Math.min(10, slot * 0.62))
                                            var base = height - 2
                                            var maxH = height - 10
                                            ctx.fillStyle = track
                                            ctx.fillRect(0, base - 1, width, 1)
                                            for (var i = 0; i < n; i++) {
                                                var h = peak > 0 ? series[i].value / peak * maxH : 0
                                                var x = i * slot + (slot - barW) / 2
                                                if (h > 0) {
                                                    if (h < 1) {
                                                        h = 1
                                                    }
                                                    h = h * revealProgress
                                                }
                                                if (h > 0) {
                                                    ctx.fillStyle = i === hoveredIndex ? hoverFill : fill
                                                    ctx.fillRect(x, base - h, barW, h)
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton

                                        function updateHover(px) {
                                            var s = historyCanvas.series
                                            if (!s || s.length === 0 || historyCanvas.width <= 0) {
                                                historyCanvas.hoveredIndex = -1
                                                return
                                            }
                                            var slot = historyCanvas.width / s.length
                                            historyCanvas.hoveredIndex =
                                                Math.max(0, Math.min(s.length - 1, Math.floor(px / slot)))
                                        }

                                        onEntered: updateHover(mouseX)
                                        onPositionChanged: updateHover(mouseX)
                                        onExited: historyCanvas.hoveredIndex = -1
                                    }

                                    Rectangle {
                                        id: hoverLine
                                        visible: historyCanvas.hoveredIndex >= 0
                                        width: 1
                                        height: parent.height
                                        color: Kirigami.Theme.highlightColor
                                        opacity: 0.6
                                        x: {
                                            var s = historyCanvas.series
                                            var idx = historyCanvas.hoveredIndex
                                            if (!s || s.length === 0 || idx < 0 || idx >= s.length) {
                                                return 0
                                            }
                                            var slot = historyCanvas.width / s.length
                                            return Math.round(idx * slot + slot / 2)
                                        }
                                    }

                                    Rectangle {
                                        id: hoverTooltip
                                        visible: historyCanvas.hoveredIndex >= 0
                                        width: hoverTooltipColumn.width + Kirigami.Units.largeSpacing
                                        height: hoverTooltipColumn.height + Kirigami.Units.smallSpacing * 2
                                        y: 0
                                        x: {
                                            var s = historyCanvas.series
                                            var idx = historyCanvas.hoveredIndex
                                            if (!s || s.length === 0 || idx < 0 || idx >= s.length) {
                                                return 0
                                            }
                                            var slot = historyCanvas.width / s.length
                                            var center = idx * slot + slot / 2
                                            return Math.max(0, Math.min(historyCanvas.width - width,
                                                                        Math.round(center - width / 2)))
                                        }
                                        color: Kirigami.Theme.backgroundColor
                                        radius: Kirigami.Units.cornerRadius
                                        border.width: 1
                                        border.color: Qt.rgba(Kirigami.Theme.disabledTextColor.r,
                                                              Kirigami.Theme.disabledTextColor.g,
                                                              Kirigami.Theme.disabledTextColor.b, 0.35)

                                        Column {
                                            id: hoverTooltipColumn
                                            anchors.centerIn: parent
                                            width: childrenRect.width
                                            height: childrenRect.height
                                            spacing: 0

                                            PlasmaComponents.Label {
                                                width: Math.max(0, Math.min(implicitWidth,
                                                                            historyChart.width - Kirigami.Units.largeSpacing))
                                                elide: Text.ElideRight
                                                text: {
                                                    var s = historyCanvas.series
                                                    var idx = historyCanvas.hoveredIndex
                                                    return s && idx >= 0 && idx < s.length
                                                        ? root.formatTooltipDate(s[idx].date)
                                                        : ""
                                                }
                                                color: Kirigami.Theme.disabledTextColor
                                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            }

                                            PlasmaComponents.Label {
                                                width: Math.max(0, Math.min(implicitWidth,
                                                                            historyChart.width - Kirigami.Units.largeSpacing))
                                                elide: Text.ElideRight
                                                text: {
                                                    var s = historyCanvas.series
                                                    var idx = historyCanvas.hoveredIndex
                                                    if (!s || idx < 0 || idx >= s.length) {
                                                        return ""
                                                    }
                                                    var code = modelData.costSummary
                                                        ? modelData.costSummary.currencyCode
                                                        : "USD"
                                                    return root.historyTooltipValues(s[idx],
                                                                                     root.costHistoryMetric,
                                                                                     code)
                                                }
                                                color: Kirigami.Theme.textColor
                                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    visible: modelData.costSummary
                                        && modelData.costSummary.daily
                                        && modelData.costSummary.daily.length > 0
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    PlasmaComponents.Label {
                                        text: {
                                            var s = historyCanvas.series
                                            return s && s.length > 0 ? root.formatMonthDay(s[0].date) : ""
                                        }
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    PlasmaComponents.Label {
                                        text: {
                                            var peak = historyCanvas.peak
                                            if (!(peak > 0)) {
                                                return i18n("No activity")
                                            }
                                            var peakDate = root.formatMonthDay(root.historyPeakDate(historyCanvas.series))
                                            if (root.costHistoryMetric === "tokens") {
                                                return i18n("Peak %1 (%2)", root.formatTokenCount(peak), peakDate)
                                            }
                                            var code = modelData.costSummary ? modelData.costSummary.currencyCode : "USD"
                                            return i18n("Peak %1 (%2)", root.formatCurrency(peak, code), peakDate)
                                        }
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }

                                    PlasmaComponents.Label {
                                        text: {
                                            var s2 = historyCanvas.series
                                            return s2 && s2.length > 0 ? root.formatMonthDay(s2[s2.length - 1].date) : ""
                                        }
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                Repeater {
                                    model: modelData.costSummary && modelData.costSummary.models
                                        ? modelData.costSummary.models.slice(0, 3)
                                        : []

                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: index === 0 ? Kirigami.Units.largeSpacing : 0
                                        spacing: Kirigami.Units.smallSpacing

                                        PlasmaComponents.Label {
                                            text: modelData.modelName
                                            color: Kirigami.Theme.textColor
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize + 1
                                        }

                                        PlasmaComponents.Label {
                                            text: root.formatCostAndTokens(
                                                modelData.totalCost,
                                                modelData.totalTokens,
                                                modelData.currencyCode || "USD")
                                            color: Kirigami.Theme.disabledTextColor
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize + 1
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                                        }
                                    }
                                }

                                PlasmaComponents.Label {
                                    visible: modelData.costSummary
                                        && modelData.costSummary.source
                                        && modelData.costSummary.source.length > 0
                                    text: modelData.costSummary && modelData.costSummary.source === "local"
                                        ? i18n("Local token-cost estimate")
                                        : i18n("Source: %1", modelData.costSummary ? modelData.costSummary.source : "")
                                    color: Kirigami.Theme.disabledTextColor
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.currentTab === "limits"
                                    && modelData.creditsRemaining !== null
                                    && modelData.creditsRemaining !== undefined

                                ColumnLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Layout.fillWidth: true

                                    Kirigami.Heading {
                                        text: i18n("Credits")
                                        level: 4
                                        Layout.fillWidth: true
                                    }

                                    PlasmaComponents.Label {
                                        visible: root.showEmailInWidget && modelData.account
                                        text: modelData.account || ""
                                        color: Kirigami.Theme.disabledTextColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                PlasmaComponents.Label {
                                    text: root.formatCredits(modelData.creditsRemaining)
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignTop
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.currentTab === "limits"
                                    && modelData.dashboardSummary && modelData.dashboardSummary.length > 0
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Heading {
                                    text: i18n("Dashboard")
                                    level: 4
                                    Layout.fillWidth: true
                                }

                                Repeater {
                                    model: modelData.dashboardSummary || []

                                    delegate: PlasmaComponents.Label {
                                        text: modelData
                                        color: Kirigami.Theme.disabledTextColor
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            PlasmaComponents.Label {
                                visible: root.currentTab === "usage"
                                    && root.showCostSummary
                                    && root.costErrorMessage.length > 0
                                    && (!modelData.costSummary)
                                text: root.costErrorMessage
                                color: Kirigami.Theme.disabledTextColor
                                wrapMode: Text.WordWrap
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.fillWidth: true
                            }

                            PlasmaComponents.Label {
                                visible: root.currentTab === "usage"
                                    && (!modelData.costSummary)
                                    && root.costErrorMessage.length === 0
                                text: !root.showCostSummary
                                    ? i18n("Enable \"Show local cost summary\" in widget settings to see usage history.")
                                    : i18n("No local usage history for this provider yet.")
                                color: Kirigami.Theme.disabledTextColor
                                wrapMode: Text.WordWrap
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Item {
                visible: root.entries.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.75
                Layout.alignment: Qt.AlignBottom

                SegmentedPill {
                    id: tabPill
                    width: Math.min(parent.width, Kirigami.Units.gridUnit * 12)
                    height: parent.height
                    anchors.horizontalCenter: parent.horizontalCenter
                    items: [
                        { text: i18n("Limits"), value: "limits" },
                        { text: i18n("Usage"), value: "usage" }
                    ]
                    currentValue: root.currentTab
                    onActivated: function(value) { root.selectTab(value) }
                }
            }

            PlasmaComponents.Label {
                visible: root.entries.length === 0
                text: root.generatedAt.length > 0 ? i18n("Updated %1", root.generatedAt) : ""
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    component SegmentedPill: Rectangle {
        id: pill

        property var items: []
        property string currentValue: ""
        property real segmentWidth: Kirigami.Units.gridUnit * 3

        signal activated(string value)

        readonly property int segmentCount: items && items.length > 0 ? items.length : 1
        readonly property int currentIndex: {
            for (var i = 0; i < items.length; i++) {
                if (items[i] && items[i].value === currentValue) {
                    return i
                }
            }
            return 0
        }

        implicitWidth: segmentWidth * segmentCount
        implicitHeight: Kirigami.Units.gridUnit * 1.75
        width: implicitWidth
        height: implicitHeight
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.disabledTextColor.r,
                       Kirigami.Theme.disabledTextColor.g,
                       Kirigami.Theme.disabledTextColor.b, 0.16)

        Rectangle {
            id: thumb
            width: (pill.width - 6) / pill.segmentCount
            height: pill.height - 6
            anchors.verticalCenter: parent.verticalCenter
            x: 3 + pill.currentIndex * width
            radius: height / 2
            color: Kirigami.Theme.highlightColor

            Behavior on x {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: pill.items

                delegate: Item {
                    width: pill.width / pill.segmentCount
                    height: pill.height

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: modelData.text
                        font.weight: pill.currentValue === modelData.value ? Font.DemiBold : Font.Normal
                        color: pill.currentValue === modelData.value
                            ? Kirigami.Theme.highlightedTextColor
                            : Kirigami.Theme.textColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: pill.activated(modelData.value)
                    }
                }
            }
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            if (data["exit code"] && data["exit code"] !== 0 && !(data.stdout || "").length) {
                var errorEntry = root.normalizeEntry({
                    provider: root.activeProvider,
                    source: root.activeSource,
                    error: {
                        kind: "runtime",
                        message: data.stderr || i18n("Exit code %1", data["exit code"])
                    }
                })
                if (root.stopForCodexAuthentication([errorEntry])) {
                    return
                }
                root.appendFailedEntries([errorEntry])
                root.tryNextCandidate()
                return
            }
            var result = root.parsePayload(data.stdout || "")
            if (!result.ok) {
                var parseErrorEntry = root.normalizeEntry({
                    provider: root.activeProvider,
                    source: root.activeSource,
                    error: { kind: "runtime", message: result.error + (result.detail ? ": " + result.detail : "") }
                })
                root.appendFailedEntries([parseErrorEntry])
                root.tryNextCandidate()
                return
            }
            if (!result.usable && root.stopForCodexAuthentication(result.entries)) {
                return
            }
            if (!result.usable && root.pendingCandidates.length > 0) {
                root.appendFailedEntries(result.entries)
                root.tryNextCandidate()
                return
            }
            root.loading = false
            root.errorMessage = ""
            root.errorDetail = ""
            root.generatedAt = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
            var visibleEntries = root.filterUnavailableEntries(result.entries)
            var updatedEntries = []
            for (var i = 0; i < visibleEntries.length; i++) {
                updatedEntries.push(root.withCostSummary(visibleEntries[i]))
            }
            root.entries = updatedEntries
            // Clamp selection, keep current tab if still valid.
            if (root.selectedEntryIndex >= updatedEntries.length) {
                root.selectedEntryIndex = 0
            }
        }
    }

    Plasma5Support.DataSource {
        id: costExecutable
        engine: "executable"
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            root.costLoading = false
            if (data["exit code"] && data["exit code"] !== 0 && !(data.stdout || "").length) {
                root.costErrorMessage = data.stderr || i18n("Cost scan failed with exit code %1", data["exit code"])
                root.costSummaries = ({})
                root.applyCostSummaries()
                return
            }
            var result = root.parseCostPayload(data.stdout || "")
            if (!result.ok) {
                root.costErrorMessage = result.error
                root.costSummaries = ({})
                root.applyCostSummaries()
                return
            }
            root.costErrorMessage = ""
            root.costSummaries = result.summaries
            root.applyCostSummaries()
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshSeconds * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onRefreshSecondsChanged: {
        refreshTimer.restart()
        refresh()
    }

    onCodexbarCommandChanged: refresh()
    onSelectedProviderChanged: refresh()
    onSelectedSourceChanged: refresh()
    onHideUnavailableProvidersChanged: refresh()
    onShowCostSummaryChanged: refreshCost()
    onShowCreditsInPanelChanged: panelText()
    onShowUsedPercentInPanelChanged: panelText()
    onShowProviderInPanelChanged: panelText()
}
