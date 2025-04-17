import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';

@Component({
  selector: 'mst-logo-circle',
  imports: [CommonModule],
  templateUrl: './logo-circle.component.html',
  styleUrl: './logo-circle.component.scss'
})
export class LogoCircleComponent {
  @Input()
  public size: 'sm' | 'md' = 'md';

  @Input()
  public sourceImage: string | null = null;

  @Input()
  public title = '';
}
