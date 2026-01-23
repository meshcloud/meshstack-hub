import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';

import { CardComponent } from 'app/shared/card';

import { PlatformCard } from './platform-card';

@Component({
  selector: 'mst-platform-cards',
  imports: [CommonModule, CardComponent],
  templateUrl: './platform-cards.component.html',
  styleUrl: './platform-cards.component.scss',
})
export class PlatformCardsComponent {
  @Input()
  public cards!: PlatformCard[];

  public logoBackgroundColors: { [key: string]: string } = {};

  public onBackgroundColorExtracted(cardTitle: string, color: string): void {
    this.logoBackgroundColors[cardTitle] = color;
  }

  public getCategoryLabel(category?: 'hyperscaler' | 'european' | 'china' | 'devops' | 'private-cloud'): { emoji: string; text: string } | null {
    if (!category) return null;

    switch (category) {
      case 'hyperscaler':
        return { emoji: '🌐', text: 'Hyperscaler' };
      case 'european':
        return { emoji: '🇪🇺', text: 'European' };
      case 'china':
        return { emoji: '🇨🇳', text: 'China' };
      case 'devops':
        return { emoji: '🔧', text: 'DevOps' };
      case 'private-cloud':
        return { emoji: '🔒', text: 'Private Cloud' };
      default:
        return null;
    }
  }
}
