"use client";

import { Dataflow03, List } from "@untitledui/icons";
import { useQueryStates } from "nuqs";
import { useTransition } from "react";
import { ButtonGroup, ButtonGroupItem } from "@/components/base/button-group/button-group";
import { viewParsers } from "@/lib/list-params";

/** List / Tree switch for tree doctypes (`?view=tree`, re-rendered on the server). */
export function ViewToggle({ view }: { view: "list" | "tree" }) {
    const [, startTransition] = useTransition();
    const [, setParams] = useQueryStates(viewParsers, { shallow: false, startTransition });

    return (
        <ButtonGroup
            size="sm"
            aria-label="View"
            selectedKeys={[view]}
            disallowEmptySelection
            onSelectionChange={(keys) => void setParams({ view: keys.has("tree") ? "tree" : null })}
        >
            <ButtonGroupItem id="list" iconLeading={List}>
                List
            </ButtonGroupItem>
            <ButtonGroupItem id="tree" iconLeading={Dataflow03}>
                Tree
            </ButtonGroupItem>
        </ButtonGroup>
    );
}
