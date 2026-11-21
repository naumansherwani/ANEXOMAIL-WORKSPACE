export type DeskModuleStatus = "planned" | "building" | "live";
export type DeskGroup = "Anexomail Workspace" | "Admin Desk" | "Company";
export type DeskModule = { key: string; group: DeskGroup; label: string; what: string; tech: string; phase: string; founderSource: string | null; status: DeskModuleStatus };
