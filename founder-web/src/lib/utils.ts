import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
/** shadcn helper: merge class names, later Tailwind utilities win. */
export const cn = (...inputs: ClassValue[]) => twMerge(clsx(inputs));
