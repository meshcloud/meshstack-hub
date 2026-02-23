import { Directive, ElementRef, AfterViewInit } from '@angular/core';
import Prism from 'prismjs';
import 'prismjs/components/prism-hcl';

@Directive({
  selector: 'code[highlight]',
  standalone: true
})
export class HighlightDirective implements AfterViewInit {
  constructor(private el: ElementRef) {}

  ngAfterViewInit(): void {
    Prism.highlightElement(this.el.nativeElement);
  }
}


