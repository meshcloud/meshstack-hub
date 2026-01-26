import { CommonModule } from '@angular/common';
import { Component, Input, Output, EventEmitter } from '@angular/core';
import { Router, RouterModule } from '@angular/router';
import ColorThief from 'colorthief';

@Component({
  selector: 'mst-card',
  imports: [RouterModule, CommonModule],
  templateUrl: './card.component.html',
  styleUrl: './card.component.scss',
  standalone: true
})
export class CardComponent {
  @Input()
  public label = '';

  @Input()
  public routePath = '';

  @Input()
  public accentColor = '';

  @Input()
  public set logoSourceImage(value: string | null) {
    this._logoSourceImage = value;
    this.extractLogoColor();
  }

  public get logoSourceImage(): string | null {
    return this._logoSourceImage;
  }

  @Output()
  public backgroundColorExtracted = new EventEmitter<string>();

  private _logoSourceImage: string | null = '';

  constructor(private router: Router) { }

  public navigateToRoutePath(): void {
    if (this.routePath) {
      this.router.navigate([this.routePath]);
    }
  }

  private extractLogoColor(): void {
    if (!this.logoSourceImage) {
      return;
    }

    if (typeof window !== 'undefined') {
      const img = new Image();
      img.src = this.logoSourceImage;
      img.onload = () => {
        const colorThief = new ColorThief();
        const dominantColor = colorThief.getColor(img);
        this.backgroundColorExtracted.emit(`rgba(${dominantColor.join(',')}, 0.1)`);
      };
    }
  }
}
