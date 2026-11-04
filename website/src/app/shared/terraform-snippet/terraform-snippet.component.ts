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
  @Input()
  public code = '';

  public readonly fileName = 'meshstack_integration.tf';

  public sectionVms: SectionVm[] = [];

  @Input()
  public set sections(sections: TerraformSnippetSection[]) {
    this.sectionVms = sections.map(section => ({
      ...section,
      lineCount: section.code.split('\n').length,
      expanded: !section.collapsed
    }));
  }

  public download(): void {
    const url = URL.createObjectURL(new Blob([this.code], { type: 'text/plain' }));
    const link = document.createElement('a');

    link.href = url;
    link.download = this.fileName;
    link.click();
    URL.revokeObjectURL(url);
  }
}
