import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
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
  public set borderColorSourceImage(value: string | null) {
    this._borderColorSourceImage = value;
    this.updateBorderColor();
  }

  public get borderColorSourceImage(): string | null {
    return this._borderColorSourceImage;
  }

  public borderColor = '';

  private _borderColorSourceImage: string| null = '';

  constructor(private router: Router) { }

  public navigateToRoutePath(): void {
    if (this.routePath) {
      this.router.navigate([this.routePath]);
    }
  }

  private updateBorderColor(): void {
    if (!this.borderColorSourceImage) {
      this.borderColor = '';

      return;
    }

    if (typeof window !== 'undefined') {
      const img = new Image();
      img.src = this.borderColorSourceImage;
      img.onload = () => {
        const colorThief = new ColorThief();
        const dominantColor = colorThief.getColor(img);
        this.borderColor = `rgb(${dominantColor.join(',')})`;
      };
    }
  }
}
