import { AfterViewInit, Directive, ElementRef } from '@angular/core';
import Prism from 'prismjs';
import 'prismjs/components/prism-hcl';

@Directive({
  selector: 'code[mstHighlight]',
  standalone: true
})
export class HighlightDirective implements AfterViewInit {
  constructor(private el: ElementRef) {}

  public ngAfterViewInit(): void {
    Prism.highlightElement(this.el.nativeElement);
  }
}
