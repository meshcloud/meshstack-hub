import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';

import { HighlightDirective } from 'app/shared/directives';

export interface TerraformSnippetSection {
  title: string;
  collapsed: boolean;
  code: string;
}

interface SectionVm extends TerraformSnippetSection {
  lineCount: number;
  expanded: boolean;
}

@Component({
  selector: 'mst-terraform-snippet',
  imports: [CommonModule, HighlightDirective],
  templateUrl: './terraform-snippet.component.html',
  // Prism replaces the server-rendered code text with highlighted spans, which hydration can't match.
  host: { ngSkipHydration: 'true' }
})
export class TerraformSnippetComponent {
  public sectionVms: SectionVm[] = [];

  @Input()
  public set sections(sections: TerraformSnippetSection[]) {
    this.sectionVms = sections.map(section => ({
      ...section,
      lineCount: section.code.split('\n').length,
      expanded: !section.collapsed
    }));
  }
}
