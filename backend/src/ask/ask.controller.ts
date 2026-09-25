import { Body, Controller, HttpException, HttpStatus, Post, Req, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { AskService, type AskEvent } from './ask.service.js';
import { AskDto } from './dto/ask.dto.js';

@Controller('ask')
@UseGuards(JwtAuthGuard)
export class AskController {
  /** Answers are expensive (a local model run), so one at a time per user. */
  private readonly inFlight = new Set<string>();

  constructor(private readonly askService: AskService) {}

  /**
   * Streams the answer as NDJSON (one {@link AskEvent} per line) so the app
   * can show progress, sources, and the answer as it's written.
   */
  @Post()
  async ask(@Req() request: AuthedRequest, @Body() dto: AskDto, @Res() response: Response) {
    const userId = request.userId;
    if (this.inFlight.has(userId)) {
      throw new HttpException('Already answering one of your questions', HttpStatus.TOO_MANY_REQUESTS);
    }
    this.inFlight.add(userId);

    const abort = new AbortController();
    response.on('close', () => abort.abort());
    response.status(200).setHeader('Content-Type', 'application/x-ndjson');
    response.setHeader('Cache-Control', 'no-cache');
    response.flushHeaders();
    const emit = (event: AskEvent) => {
      if (!response.writableEnded) response.write(`${JSON.stringify(event)}\n`);
    };

    const location = dto.lat !== undefined && dto.lng !== undefined ? { lat: dto.lat, lng: dto.lng } : null;
    try {
      await this.askService.answer(dto.question.trim(), location, emit, abort.signal);
    } catch (error) {
      if (!abort.signal.aborted) {
        emit({ type: 'error', message: "Couldn't get an answer right now. Try again in a moment." });
        console.error('Ask HERE failed', error);
      }
    } finally {
      this.inFlight.delete(userId);
      response.end();
    }
  }
}
