import type { ActivityAction, StoreRole } from "./types";

export type Capability =
  | "viewInventory"
  | "stock"
  | "editItems"
  | "deleteItems"
  | "createCategories"
  | "deleteCategories"
  | "viewActivity"
  | "correctStock"
  | "manageTeam"
  | "renameStore";

const capabilities: Record<StoreRole, Record<Capability, boolean>> = {
  staff: {
    viewInventory: true, stock: true, editItems: false, deleteItems: false, createCategories: false,
    deleteCategories: false, viewActivity: false, correctStock: false, manageTeam: false, renameStore: false,
  },
  manager: {
    viewInventory: true, stock: true, editItems: true, deleteItems: false, createCategories: true,
    deleteCategories: false, viewActivity: true, correctStock: false, manageTeam: false, renameStore: false,
  },
  owner: {
    viewInventory: true, stock: true, editItems: true, deleteItems: true, createCategories: true,
    deleteCategories: true, viewActivity: true, correctStock: true, manageTeam: true, renameStore: true,
  },
};

export function can(role: StoreRole | null | undefined, capability: Capability): boolean {
  return Boolean(role && capabilities[role][capability]);
}

export function canViewActivityAction(role: StoreRole | null | undefined, action: ActivityAction): boolean {
  if (role === "owner") return true;
  return role === "manager" && (action === "stock_in" || action === "stock_out" || action === "stock_correction");
}

export function tabsForRole(role: StoreRole | null | undefined): ("inventory" | "categories" | "activity" | "team" | "settings")[] {
  if (role === "owner") return ["inventory", "categories", "activity", "team", "settings"];
  if (role === "manager") return ["inventory", "categories", "activity"];
  return ["inventory", "categories"];
}
