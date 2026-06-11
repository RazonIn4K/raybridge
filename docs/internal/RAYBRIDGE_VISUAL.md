# Raybridge Visual Architecture Guide

## 🌐 Complete System Flow

```mermaid
graph TB
    subgraph "User Environment"
        U[You]
        CD[Claude Desktop]
    end
    
    subgraph "MCP Servers"
        Z[Zen MCP Server<br/>GitHub Copilot API]
        RB[Raybridge MCP Server<br/>Raycast Extensions]
        FS[Filesystem MCP]
        PY[Playwright MCP]
        DO[MCP_DOCKER]
        C7[Context-7 MCP]
    end
    
    subgraph "Raybridge Internals"
        subgraph "Core"
            RBC[Raybridge Core]
            DIS[Extension Discovery]
            FIL[Config Filter]
            EXE[Worker Executor]
        end
        
        subgraph "Enabled Extensions"
            GH[GitHub Extension]
            GC[Google Calendar]
            SL[Slack]
            OB[Obsidian]
            AN[Apple Notes]
            AR[Apple Reminders]
            KP[Kill Process]
            AC[Arc Browser]
            DM[Downloads Manager]
            VD[Video Downloader]
            B64[Base64]
            SH[Shodan]
            XC[Xcode]
            SV[SVGL]
        end
    end
    
    subgraph "External Services"
        GHA[GitHub API]
        GCA[Google Calendar API]
        GWA[Google Workspace API]
        SLA[Slack API]
        APA[Apple APIs]
        SHA[Shodan API]
    end
    
    subgraph "Local Resources"
        FS2[Local Filesystem]
        OB2[Obsidian Vaults]
        AN2[Apple Notes DB]
        AR2[Reminders App]
        AC2[Arc Browser]
        DM2[Downloads Folder]
        XC2[Xcode Projects]
    end
    
    U --> CD
    CD --> Z
    CD --> RB
    CD --> FS
    CD --> PY
    CD --> DO
    CD --> C7
    
    RB --> RBC
    RBC --> DIS
    RBC --> FIL
    RBC --> EXE
    
    DIS --> GH
    DIS --> GC
    DIS --> SL
    DIS --> OB
    DIS --> AN
    DIS --> AR
    DIS --> KP
    DIS --> AC
    DIS --> DM
    DIS --> VD
    DIS --> B64
    DIS --> SH
    DIS --> XC
    DIS --> SV
    
    EXE --> GH
    EXE --> GC
    EXE --> SL
    EXE --> OB
    EXE --> AN
    EXE --> AR
    EXE --> KP
    EXE --> AC
    EXE --> DM
    EXE --> VD
    EXE --> B64
    EXE --> SH
    EXE --> XC
    EXE --> SV
    
    GH --> GHA
    GC --> GCA
    SL --> SLA
    SH --> SHA
    
    OB --> OB2
    AN --> AN2
    AR --> AR2
    KP --> FS2
    AC --> AC2
    DM --> DM2
    XC --> XC2
    
    classDef mcp fill:#e1f5fe
    classDef raybridge fill:#f3e5f5
    classDef external fill:#e8f5e8
    classDef local fill:#fff3e0
    
    class Z,RB,FS,PY,DO,C7 mcp
    class RBC,DIS,FIL,EXE,GH,GC,SL,OB,AN,AR,KP,AC,DM,VD,B64,SH,XC,SV raybridge
    class GHA,GCA,GWA,SLA,APA,SHA external
    class FS2,OB2,AN2,AR2,AC2,DM2,XC2 local
```

## 🔄 Tool Execution Pattern

```mermaid
sequenceDiagram
    participant U as User
    participant CD as Claude Desktop
    participant RB as Raybridge
    participant CF as Config Filter
    participant EX as Extension
    participant API as External API
    
    U->>CD: "Create a GitHub issue"
    CD->>RB: call_tool("github", {
        tool_name: "create-issue",
        input: {repo, title, body}
    })
    
    RB->>CF: Check if github.enabled
    CF-->>RB: ✅ Allowed
    
    RB->>CF: Check if "create-issue" in tools
    CF-->>RB: ✅ Allowed
    
    RB->>EX: Execute create-issue
    EX->>API: POST /repos/{repo}/issues
    API-->>EX: Issue created
    EX-->>RB: Issue URL
    
    RB-->>CD: "Issue created: https://github.com/..."
    CD-->>U: "I've created the GitHub issue for you"
```

## 📊 Extension Categories

```mermaid
mindmap
  root((Raybridge))
    Development
      GitHub
        Issues
        PRs
        Workflows
      Xcode
        Projects
        Simulators
    Communication
      Slack
        Channels
        Messages
        Status
    Productivity
      Google Calendar
        Events
        Availability
      Apple Reminders
        Tasks
        Lists
    Knowledge Management
      Obsidian
        Notes
        Search
        Vaults
      Apple Notes
        Create
        Search
    System Utilities
      Kill Process
        List
        Terminate
      Downloads Manager
        Latest
        Copy
    Media & Content
      Video Downloader
        Download
        Transcript
      SVGL
        Logos
        Components
    Security
      Shodan
        Host Search
        Alerts
    Browser
      Arc
        Tabs
        Spaces
        History
```

## 🔐 Security Model

```mermaid
graph LR
    subgraph "Security Layers"
        L1[Layer 1: MCP Protocol<br/>Isolated execution]
        L2[Layer 2: Allowlist Mode<br/>Only enabled extensions]
        L3[Layer 3: Tool Whitelist<br/>Specific tools per extension]
        L4[Layer 4: Capability Gates<br/>Raycast API permissions]
        L5[Layer 5: System Permissions<br/>macOS permissions]
    end
    
    subgraph "Protected Resources"
        FS[File System]
        NET[Network]
        SYS[System Processes]
        APP[Applications]
    end
    
    L1 --> L2 --> L3 --> L4 --> L5
    
    L5 --> FS
    L5 --> NET
    L5 --> SYS
    L5 --> APP
    
    classDef security fill:#ffebee
    classDef resource fill:#e8f5e8
    
    class L1,L2,L3,L4,L5 security
    class FS,NET,SYS,APP resource
```

## 🚀 Doppler Integration Flow

```mermaid
graph TB
    subgraph "Without Doppler"
        CD1[Claude Desktop] --> RB1[Raybridge]
        RB1 --> ENV1[Environment Variables]
        ENV1 --> API1[External APIs]
    end
    
    subgraph "With Doppler"
        CD2[Claude Desktop] --> DOP[Doppler CLI]
        DOP --> RB2[Raybridge]
        RB2 --> ENV2[Injected Secrets]
        ENV2 --> API2[External APIs]
    end
    
    subgraph "Doppler Project"
        DP[Doppler Project: raybridge]
        DC[Config: prod]
        DS[Secrets: API keys, tokens]
    end
    
    DP --> DOP
    DC --> DOP
    DS --> DOP
    
    classDef doppler fill:#e3f2fd
    classDef normal fill:#f5f5f5
    
    class DOP,DP,DC,DS doppler
    class CD1,RB1,ENV1,API1,CD2,RB2,ENV2,API2 normal
```

## 📈 Performance Characteristics

```mermaid
gantt
    title Raybridge Tool Execution Timeline
    dateFormat X
    axisFormat %s
    
    section Tool Call
    Request Validation   :0, 10ms
    Config Check        :10, 5ms
    Worker Spawn        :15, 50ms
    Extension Load      :65, 20ms
    API Call            :85, 200ms
    Response Process    :285, 10ms
    
    section Parallel Execution
    Tool 1 :0, 300
    Tool 2 :50, 350
    Tool 3 :100, 400
```

## 🎯 Usage Recommendations

### High-Value Extensions (Daily Use)
1. **GitHub** - Essential for development workflow
2. **Obsidian** - Knowledge management
3. **Slack** - Team communication
4. **Google Calendar** - Meeting management

### situational Extensions
1. **Apple Notes** - Quick notes when Obsidian is overkill
2. **Downloads Manager** - File management
3. **Base64** - Encoding/decoding utilities

### Advanced/Power User
1. **Shodan** - Security research (requires API key)
2. **Xcode** - iOS/macOS development
3. **Kill Process** - System administration

---

This visual guide helps you understand how Raybridge fits into your development ecosystem and how to leverage it effectively.
