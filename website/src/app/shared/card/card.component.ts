import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { Router, RouterModule } from '@angular/router';
import ColorThief from 'colorthief';

import { Card, CardConfig } from './card';

@Component({
  selector: 'mst-card',
  imports: [RouterModule, CommonModule],
  templateUrl: './card.component.html',
  styleUrl: './card.component.scss',
  standalone: true
})
export class CardComponent {
  @Input()
  public set card(value: Card) {
    this._card = value;
    this.updateBorderColor();
  }

  public get card(): Card {
    return this._card;
  }

  @Input()
  public set config(value: CardConfig) {
    this._config = value;
    this.updateBorderColor();
  }

  public get config(): CardConfig {
    return this._config;
  }

  public borderColor = '';

  private _card!: Card;

  private _config: CardConfig = {
    titleNextToLogo: false,
    showFooter: true,
    borderDominantColorOfLogo: false
  };

  constructor(private router: Router) { }

  public navigateToRoutePath(): void {
    if (this.card.routePath) {
      this.router.navigate([this.card.routePath]);
    }
  }

  private updateBorderColor(): void {
    if (!this.card?.cardLogo || !this.config.borderDominantColorOfLogo) {
      this.borderColor = '';

      return;
    }

    if (typeof window !== 'undefined') {
      const img = new Image();
      img.src = this.card.cardLogo;
      img.onload = () => {
        const colorThief = new ColorThief();
        const dominantColor = colorThief.getColor(img);
        this.borderColor = `rgb(${dominantColor.join(',')})`;
      };
    }
  }
}
