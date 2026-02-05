import { CommonModule } from '@angular/common';
import { Component, Input, Output, EventEmitter } from '@angular/core';
import { Router, RouterModule } from '@angular/router';
import { extractLogoColor } from '../util/logo-color.util';
import { Observable, of, map, switchMap, startWith } from 'rxjs';

const DEFAULT_CARD_BG_COLOR = 'rgba(203,213,225,0.3)';

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

  private _logoSourceImage: string | null = '';

  @Input()
  set logoSourceImage(value: string | null) {
    this._logoSourceImage = value;
    this._logoSourceImage$ = of(value);
  }
  get logoSourceImage(): string | null {
    return this._logoSourceImage;
  }

  @Output()
  public backgroundColorExtracted = new EventEmitter<string>();

  private _logoSourceImage$: Observable<string | null> = of(null);

  public logoBackgroundColor$: Observable<string> = of(DEFAULT_CARD_BG_COLOR);

  constructor(private router: Router) {
    // Set up the reactive logo background color observable
    this.logoBackgroundColor$ = this._logoSourceImage$.pipe(
      switchMap(logo =>
        logo
          ? extractLogoColor(logo).pipe(
              map(color => color || DEFAULT_CARD_BG_COLOR),
              map(color => {
                this.backgroundColorExtracted.emit(color);
                return color;
              })
            )
          : of(DEFAULT_CARD_BG_COLOR)
      ),
      startWith(DEFAULT_CARD_BG_COLOR)
    );
  }

  public navigateToRoutePath(): void {
    if (this.routePath) {
      this.router.navigate([this.routePath]);
    }
  }
}
