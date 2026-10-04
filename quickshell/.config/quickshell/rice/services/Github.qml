pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// GitHub activity through the gh CLI (its stored login; nothing kept here):
// the contribution calendar and the latest commits of recently pushed repos.
// state: "loading" | "ok" | "error" (gh missing / not logged in / offline)
QtObject {
    id: root

    property string state_: "loading"
    property string error: ""
    property string login: ""
    property int total: 0          // contributions in the last year
    property var days: []          // [{ date (Date), count, level 0-4 }], oldest first
    property var commits: []       // [{ repo, message, date (Date), oid, url, private }]
    property string name: ""
    property int followers: 0
    property int following: 0
    property int starred: 0
    property int repoCount: 0
    property var repos: []         // [{ name, private, stars, forks, pushed (Date), lang, langColor, description, url }]
    property int prCount: 0
    property var prs: []           // [{ title, number, url, repo, updated (Date), draft }]
    property int issueCount: 0
    property var issues: []        // [{ title, number, url, repo, updated (Date) }]
    property int reviewCount: 0
    property var reviews: []       // [{ title, number, url, repo, updated (Date) }]
    property int notifications: 0
    property date updated: new Date(0)

    property var busiest: ({ count: 0, date: null })
    property int longestStreak: 0
    readonly property int today: days.length ? days[days.length - 1].count : 0
    readonly property int thisWeek: {
        let n = 0;
        for (let i = days.length - 1; i >= 0; i--) {
            n += days[i].count;
            if (days[i].date.getDay() === 1) break;   // back to Monday
        }
        return n;
    }
    // Consecutive days with contributions, ending today (or yesterday if
    // today has none yet).
    readonly property int streak: {
        let i = days.length - 1;
        if (i >= 0 && days[i].count === 0) i--;
        let n = 0;
        for (; i >= 0 && days[i].count > 0; i--) n++;
        return n;
    }

    function refresh() {
        if (!proc.running) proc.running = true;
    }
    function openNotifications() { Quickshell.execDetached(["xdg-open", "https://github.com/notifications"]); }
    function openProfile() { if (login) Quickshell.execDetached(["xdg-open", "https://github.com/" + login]); }
    function open(url) { Quickshell.execDetached(["xdg-open", url]); }

    readonly property string _query: "query { viewer { login name "
        + "followers { totalCount } following { totalCount } starredRepositories { totalCount } "
        + "pullRequests(first: 6, states: OPEN, orderBy: { field: UPDATED_AT, direction: DESC }) { totalCount "
        + "nodes { title number url updatedAt isDraft repository { nameWithOwner } } } "
        + "issues(first: 6, states: OPEN, orderBy: { field: UPDATED_AT, direction: DESC }) { totalCount "
        + "nodes { title number url updatedAt repository { nameWithOwner } } } "
        + "contributionsCollection { contributionCalendar { totalContributions "
        + "weeks { contributionDays { date contributionCount } } } } "
        + "repositories(first: " + Settings.githubRepos + ", ownerAffiliations: [OWNER, COLLABORATOR], "
        + "orderBy: { field: PUSHED_AT, direction: DESC }) { totalCount nodes { nameWithOwner isPrivate "
        + "stargazerCount forkCount pushedAt description url primaryLanguage { name color } "
        + "defaultBranchRef { target { ... on Commit { history(first: 4) { nodes { "
        + "messageHeadline committedDate abbreviatedOid url } } } } } } } } "
        + "search(query: \"is:open is:pr review-requested:@me\", type: ISSUE, first: 6) { issueCount "
        + "nodes { ... on PullRequest { title number url updatedAt repository { nameWithOwner } } } } }"

    readonly property var proc: Process {
        command: ["sh", "-c", 'gh api graphql -f query="$1" && echo && echo "@@notifications $(gh api notifications --jq length 2>/dev/null)"',
                  "sh", root._query]
        stdout: StdioCollector {
            onStreamFinished: {
                const i = this.text.lastIndexOf("@@notifications");
                if (i >= 0) root.notifications = Number(this.text.slice(i + 15).trim()) || 0;
                root._parse(i >= 0 ? this.text.slice(0, i) : this.text);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) root.error = this.text.trim().split("\n")[0]
        }
        onExited: code => { if (code !== 0) root.state_ = "error"; }
    }

    function _parse(text) {
        let o;
        try { o = JSON.parse(text); } catch (e) { return; }
        const v = o && o.data && o.data.viewer;
        if (!v) { state_ = "error"; error = (o.errors && o.errors[0] && o.errors[0].message) || "no data"; return; }
        login = v.login;
        name = v.name || v.login;
        followers = v.followers.totalCount;
        following = v.following.totalCount;
        starred = v.starredRepositories.totalCount;
        repoCount = v.repositories.totalCount;
        repos = v.repositories.nodes.map(r => ({
            name: r.nameWithOwner.split("/").pop(), private: r.isPrivate, stars: r.stargazerCount,
            forks: r.forkCount, pushed: new Date(r.pushedAt), lang: r.primaryLanguage ? r.primaryLanguage.name : "",
            langColor: r.primaryLanguage && r.primaryLanguage.color ? r.primaryLanguage.color : Theme.grey,
            description: r.description || "", url: r.url
        }));
        const item = n => ({ title: n.title, number: n.number, url: n.url, repo: n.repository.nameWithOwner,
                             updated: new Date(n.updatedAt), draft: n.isDraft === true });
        prCount = v.pullRequests.totalCount;
        prs = v.pullRequests.nodes.map(item);
        issueCount = v.issues.totalCount;
        issues = v.issues.nodes.map(item);
        const sr = o.data.search;
        reviewCount = sr ? sr.issueCount : 0;
        reviews = sr ? sr.nodes.filter(n => n && n.title).map(item) : [];
        const cal = v.contributionsCollection.contributionCalendar;
        total = cal.totalContributions;
        const flat = [];
        for (const w of cal.weeks)
            for (const d of w.contributionDays)
                flat.push({ date: new Date(d.date + "T12:00"), count: d.contributionCount });
        // Levels by quartile of this year's non-zero days, like GitHub's graph.
        const nz = flat.map(d => d.count).filter(c => c > 0).sort((a, b) => a - b);
        const q = p => nz.length ? nz[Math.min(nz.length - 1, Math.floor(nz.length * p))] : 1;
        const q1 = q(0.25), q2 = q(0.5), q3 = q(0.75);
        days = flat.map(d => Object.assign(d, {
            level: d.count === 0 ? 0 : d.count <= q1 ? 1 : d.count <= q2 ? 2 : d.count <= q3 ? 3 : 4
        }));
        const list = [];
        for (const r of v.repositories.nodes) {
            const t = r.defaultBranchRef && r.defaultBranchRef.target;
            if (!t || !t.history) continue;
            for (const c of t.history.nodes)
                list.push({ repo: r.nameWithOwner.split("/").pop(), message: c.messageHeadline,
                            date: new Date(c.committedDate), oid: c.abbreviatedOid, url: c.url, private: r.isPrivate });
        }
        commits = list.sort((a, b) => b.date - a.date).slice(0, Settings.githubCommits);
        busiest = flat.reduce((m, d) => d.count > m.count ? d : m, { count: 0, date: null });
        // Longest run of days with contributions this year.
        let run = 0, best = 0;
        for (const d of flat) { run = d.count > 0 ? run + 1 : 0; best = Math.max(best, run); }
        longestStreak = best;
        error = "";
        updated = new Date();
        state_ = "ok";
    }

    function age(d) {
        const s = (Date.now() - d.getTime()) / 1000;
        if (s < 3600) return Math.max(1, Math.floor(s / 60)) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    readonly property var timer: Timer {
        interval: Settings.githubRefreshMin * 60000
        running: Settings.showGithub
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
