import { Toaster as Sonner } from "sonner";

type ToasterProps = React.ComponentProps<typeof Sonner>;

/**
 * Toast surface — cinematic. Sits on the stage bottom-right, one plane deep,
 * platinum edge, key-light shadow. Never more than three at a time.
 */
const Toaster = ({ ...props }: ToasterProps) => {
  return (
    <Sonner
      theme="dark"
      position="bottom-right"
      visibleToasts={3}
      closeButton
      richColors={false}
      gap={10}
      className="toaster group"
      toastOptions={{
        classNames: {
          toast:
            "group toast ax-plane group-[.toaster]:rounded-xl group-[.toaster]:text-foreground group-[.toaster]:shadow-elev-2 group-[.toaster]:py-3",
          title: "group-[.toast]:ax-label",
          description: "group-[.toast]:ax-caption",
          closeButton:
            "group-[.toast]:!left-auto group-[.toast]:!right-2 group-[.toast]:!top-2 group-[.toast]:!translate-x-0 group-[.toast]:!translate-y-0 group-[.toast]:size-6 group-[.toast]:!rounded-md group-[.toast]:!border group-[.toast]:!border-border group-[.toast]:!bg-secondary group-[.toast]:!text-foreground group-[.toast]:opacity-100 hover:group-[.toast]:!bg-muted",
          actionButton:
            "group-[.toast]:ax-press group-[.toast]:rounded-md group-[.toast]:bg-primary group-[.toast]:text-primary-foreground",
          cancelButton:
            "group-[.toast]:ax-press group-[.toast]:rounded-md group-[.toast]:bg-muted group-[.toast]:text-muted-foreground",
          success: "group-[.toaster]:[&_[data-icon]]:text-success",
          error: "group-[.toaster]:[&_[data-icon]]:text-danger",
          info: "group-[.toaster]:[&_[data-icon]]:text-cyan-accent",
        },
      }}
      {...props}
    />
  );
};

export { Toaster };
