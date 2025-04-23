import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { BehaviorSubject, Observable, combineLatest, map, tap } from 'rxjs';

import { CardComponent } from 'app/shared/card';
import { LogoCircleComponent } from 'app/shared/logo-circle/logo-circle.component';
import { PlatformService } from 'app/shared/platform-logo';

interface PlatformCard {
  cardLogo: string | null;
  title: string;
  routePath: string;
}

@Component({
  selector: 'mst-platform-cards',
  imports: [CommonModule, CardComponent, LogoCircleComponent],
  templateUrl: './platform-cards.component.html',
  styleUrl: './platform-cards.component.scss',
  standalone: true
})
export class PlatformCardsComponent implements OnInit {
  @Input()
  public set searchTerm(value: string) {
    this.searchTermSubject.next(value);
  }

  @Output()
  public resultCount: EventEmitter<number> = new EventEmitter<number>();

  public cards$!: Observable<PlatformCard[]>;

  private searchTermSubject = new BehaviorSubject<string>('');

  private searchTerm$ = this.searchTermSubject.asObservable();

  constructor(private readonly platformService: PlatformService) { }

  public ngOnInit(): void {
    const platformCards$ = this.platformService.getAllPlatformData()
      .pipe(map((logos) => this.mapLogosToPlatformCards(logos)));

    this.cards$ = combineLatest([platformCards$, this.searchTerm$])
      .pipe(
        map(([cards, searchTerm]) => this.filterCardsBySearchTerm(cards, searchTerm)),
        tap(cards => this.resultCount.emit(cards.length))
      );
  }

  private mapLogosToPlatformCards(logos: Record<string, { name: string; logo: string }>): PlatformCard[] {
    return Object.entries(logos)
      .map(([key, platform]) =>
        this.createPlatformCard(platform.name, platform.logo, `/platforms/${key}`)
      );
  }

  private createPlatformCard(title: string, logoUrl: string, routePath: string): PlatformCard {
    return { cardLogo: logoUrl, title, routePath };
  }

  private filterCardsBySearchTerm(cards: PlatformCard[], searchTerm: string): PlatformCard[] {
    const searchTermLower = searchTerm.toLowerCase();

    return cards.filter(card => card.title.toLowerCase()
      .includes(searchTermLower));
  }
}
